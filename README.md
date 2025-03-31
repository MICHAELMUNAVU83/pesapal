# Pesapal

A simple Elixir client for integrating with Pesapal v3 payment gateway API.

## Installation

Add `pesapal` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pesapal, "~> 0.1.0"}
  ]
end
```

## Configuration

```elixir
# In config/config.exs (or the appropriate environment config file)
config :pesapal,
  api_base_url: "https://cybqa.pesapal.com/pesapalv3/api", # QA environment
  # api_base_url: "https://pay.pesapal.com/pesapalv3/api", # Production
  consumer_key: "your-consumer-key",
  consumer_secret: "your-consumer-secret"
```

## Features

- Authentication with Pesapal API
- IPN (Instant Payment Notification) webhook registration
- Payment initiation
- Transaction status checking

## Basic Usage

```elixir
# Authenticate
{:ok, auth_response} = Pesapal.authenticate()
token = auth_response["token"]

# Register IPN webhook
{:ok, ipn_response} = Pesapal.register_ipn("https://example.com/webhook", token)
ipn_id = ipn_response["ipn_id"]

# Initiate payment
{:ok, payment} = Pesapal.initiate_payment(
  1000,                   # amount
  "customer@example.com", # email
  "KES",                  # currency
  ipn_id,                 # from register_ipn
  token,                  # from authenticate
  [description: "Premium Subscription"] # optional params
)

# Check transaction status
{:ok, status} = Pesapal.check_transaction_status(
  payment["order_tracking_id"],
  token
)
```

## Documentation

For more detailed information, please refer to the [hexdocs](https://hexdocs.pm/pesapal).

## Author

[Michael Munavu](https://michaelmunavu.com)

## License

Chpter is released under [MIT License](https://github.com/appcues/exsentry/blob/master/LICENSE.txt)
