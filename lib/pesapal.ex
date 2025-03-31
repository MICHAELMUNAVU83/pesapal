defmodule Pesapal do
  @moduledoc """
  Handles integration with Pesapal payment gateway API (v3).

  This module provides functions to authenticate, register IPN webhooks,
  initiate payments, and check transaction statuses with the Pesapal API.

  The flow is as follows:
  1. Authenticate with Pesapal using `authenticate/2`.
  2. Register an IPN webhook using `register_ipn/2`.
  3. Initiate a payment using `initiate_payment/6`.
  4. Check the transaction status using `check_transaction_status/2`.
  5. Handle the IPN notifications sent to your webhook URL.


  For your IPN webhook, you need to set up a route in your application
  to handle incoming POST requests from Pesapal. The IPN URL should
  be publicly accessible and should be able to process the incoming
  notifications. This can be a simple post  endpoint in your application as follows


  ```elixir
  defmodule AppWeb.OrderController do
  use AppWeb, :controller

  def create(conn, params) do
    IO.inspect(params)

    # Handle the IPN notification here

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(%{message: "Success"}))
  end
  end

  # In your router.ex file, add a route for the IPN webhook

  defmodule AppWeb.Router do
    use AppWeb, :router

    scope "/api", AppWeb do
      pipe_through :api

      post "/webhook", OrderController, :create
    end
  end

  ```

  ## Configuration
  You need to set the `api_base_url` in your application configuration , as well as your consumer key and consumer secret.

  You can set this in your config file:
  ```elixir
  config :pesapal,
    api_base_url: "https://cybqa.pesapal.com/pesapalv3/api",
    consumer_key: "qkio1BGGYAXTu2JOfm7XSXNruoZsrqEW",
    consumer_secret: "osGQ364R49cXKeOYSpaOnT++rHs="
  ```

  For Production:
  ```elixir
  config :pesapal,
    api_base_url: "https://www.pesapal.com/pesapalv3/api",
    consumer_key: "qkio1BGGYAXTu2JOfm7XSXNruoZsrqEW",
    consumer_secret: "osGQ364R49cXKeOYSpaOnT++rHs="
  ```

  """

  @doc """
  Authenticates with Pesapal API and returns an access token.

  ## Returns
    * `{:ok, %{"token" => token, "expiryDate" => expiry_date}}` - Success with token details
    * `{:error, reason}` - Error with reason

  ## Examples
      iex> Pesapal.authenticate("your_key", "your_secret")
      {:ok, %{"token" => "abc123", "expiryDate" => "2023-01-01T00:00:00Z"}}
  """
  def authenticate do
    consumer_key = Application.get_env(:pesapal, :consumer_key)
    consumer_secret = Application.get_env(:pesapal, :consumer_secret)
    url = "#{Application.get_env(:pesapal, :api_base_url)}/Auth/RequestToken"

    body = %{
      "consumer_key" => consumer_key,
      "consumer_secret" => consumer_secret
    }

    post_request(url, body)
  end

  @doc """
  Registers an Instant Payment Notification (IPN) webhook with Pesapal.

  ## Parameters
    * `webhook_url` - The URL to receive payment notifications
    * `token` - The authentication token from `authenticate/2`

  ## Returns
    * `{:ok, %{"ipn_id" => ipn_id, ...}}` - Success with IPN details
    * `{:error, reason}` - Error with reason

  ## Examples
      iex> Pesapal.register_ipn("https://example.com/webhook", "abc123")
      {:ok, %{"ipn_id" => "ipn123", "url" => "https://example.com/webhook"}}
  """
  def register_ipn(webhook_url, token) do
    url = "#{Application.get_env(:pesapal, :api_base_url)}/URLSetup/RegisterIPN"

    body = %{
      "url" => webhook_url,
      "ipn_notification_type" => "POST"
    }

    post_request(url, body, token)
  end

  @doc """
  Initiates a payment transaction with Pesapal.

  ## Parameters
    * `amount` - The payment amount (numeric)
    * `email` - Customer's email address
    * `currency` - Currency code (e.g., "KES", "USD")
    * `ipn_id` - IPN ID from `register_ipn/2`
    * `callback_url` - Callback URL where customers will be redirected after successful payment
    * `token` - The authentication token from `authenticate/2`
    * `opts` - Optional parameters:
      * `:description` - Payment description (default: "Payment")
      * `:order_id` - Custom order ID (default: auto-generated)

  ## Returns
    * `{:ok, %{"order_tracking_id" => id, "redirect_url" => url, ...}}` - Success with payment details
    * `{:error, reason}` - Error with reason

  ## Examples
      iex> Pesapal.initiate_payment(1000, "user@example.com", "KES", "ipn123", "https://example.com/callback", "abc123")
      {:ok, %{"order_tracking_id" => "ord123", "redirect_url" => "https://pesapal.com/payment/..."}}

      iex>Pesapal.initiate_payment(1000, "user@example.com", "KES", "ipn123", "https://example.com/callback", "abc123", [description: "Test Payment"])
      {:ok, %{"order_tracking_id" => "ord123", "redirect_url" => "https://pesapal.com/payment/..."}}
  """
  def initiate_payment(amount, email, currency, ipn_id, callback_url, token, opts \\ []) do
    url = "#{Application.get_env(:pesapal, :api_base_url)}/Transactions/SubmitOrderRequest"

    description = Keyword.get(opts, :description, "Payment")

    body = %{
      "id" => generate_order_id(),
      "currency" => currency,
      "amount" => amount,
      "description" => description,
      "notification_id" => ipn_id,
      "callback_url" => callback_url,
      "billing_address" => %{
        "email_address" => email
      }
    }

    post_request(url, body, token)
  end

  @doc """
  Checks the status of a transaction.

  ## Parameters
    * `order_tracking_id` - The order tracking ID from `initiate_payment/5`
    * `token` - The authentication token from `authenticate/2`

  ## Returns
    * `{:ok, %{"status" => status, "payment_method" => method, ...}}` - Success with transaction details
    * `{:error, reason}` - Error with reason

  ## Examples
      iex> Pesapal.check_transaction_status("ord123", "abc123")
      {:ok, %{"status" => "COMPLETED", "payment_method" => "MPESA"}}


  ## Note
      The status code represents the payment_status_description.
      0 - INVALID
      1 - COMPLETED
      2 - FAILED
      3 - REVERSED
  """
  def check_transaction_status(order_tracking_id, token) do
    url =
      "#{Application.get_env(:pesapal, :api_base_url)}/Transactions/GetTransactionStatus?orderTrackingId=#{order_tracking_id}"

    get_request(url, token)
  end

  # Private helper functions

  @doc false
  defp post_request(url, body, token \\ nil) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    # Add authorization header if token is provided
    headers = if token, do: [{"Authorization", "Bearer #{token}"} | headers], else: headers

    case HTTPoison.post(url, Jason.encode!(body), headers) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}}
      when status_code in 200..299 ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        parsed_body = parse_error_body(response_body)
        {:error, "HTTP Error #{status_code}: #{parsed_body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  @doc false
  defp get_request(url, token) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"Authorization", "Bearer #{token}"}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}}
      when status_code in 200..299 ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        parsed_body = parse_error_body(response_body)
        {:error, "HTTP Error #{status_code}: #{parsed_body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  @doc false
  defp parse_error_body(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) ->
        error_message = decoded["error"] || decoded["message"] || inspect(decoded)
        error_message

      _ ->
        body
    end
  end

  @doc false
  defp generate_order_id do
    DateTime.utc_now()
    |> DateTime.to_string()
    |> String.replace(~r/[^0-9]/, "")
    |> String.slice(0, 14)
  end
end
