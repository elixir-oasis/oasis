# Handle Errors

When we run `mix oas.gen.plug` mix task to generate the corresponding modules, we could see the following similar output (here are only for an example)

```
...
* creating lib/oasis/gen/pre_list_pets.ex
* creating lib/oasis/gen/list_pets.ex
...
```

The `"pre_list_pets.ex"` and `"list_pets.ex"` files are in a pair, the former starts with `"pre_"` is in charge of the parse and validation to the request,
the latter is after the former's pipeline process, the latter is in charge of the detailed business logic to write, and provide a `handle_errors/2`
function to process the errors:

```
def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
  message = Map.get(reason, :message) || "Something went wrong"
  send_resp(conn, conn.status, message)
end
```

The `reason` is an `Oasis.BadRequestError` exception with these errors:

  * `Oasis.BadRequestError.Invalid`
  * `Oasis.BadRequestError.Required`
  * `Oasis.BadRequestError.JsonSchemaValidationFailed`
  * `Oasis.BadRequestError.InvalidToken`

We can use pattern math to process the potential errors like this:

```
def handle_errors(conn, %{kind: _kind, reason: {
  error: %Oasis.BadRequestError.JsonSchemaValidationFailed{} = error} = reason, stack: _stack}) do
  # inspect the `error` and `reason` to find more information about this error case.
  ...
end
def handle_errors(conn, %{kind: _kind, reason: {
  error: %Oasis.BadRequestError.InvalidToken{} = error} = reason, stack: _stack}) do
  ...
end
def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
  ...
end
```
