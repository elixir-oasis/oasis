defmodule Oasis.ValidatorTest do
  use ExUnit.Case

  alias Oasis.Validator

  test "simple type integer" do
    param = %{
      "required" => true,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{"type" => "integer", "minimum" => 10, "maximum" => 20}
      }
    }

    name = "test_name"

    assert_raise Oasis.BadRequestError,
                 ~r/Expected the value to be >= 10/,
                 fn ->
                   Validator.parse_and_validate!(param, "query", name, "1")
                 end

    assert Validator.parse_and_validate!(param, "query", name, "10") == 10
    assert Validator.parse_and_validate!(param, "query", name, "20") == 20

    assert_raise Oasis.BadRequestError,
                 ~r/Expected the value to be <= 20/,
                 fn ->
                   Validator.parse_and_validate!(param, "query", name, "21")
                 end

    assert_raise Oasis.BadRequestError,
                 ~r/Missing a required parameter/,
                 fn ->
                   Validator.parse_and_validate!(param, "query", name, nil)
                 end

    param = Map.put(param, "required", false)

    assert Validator.parse_and_validate!(param, "query", name, "15") == 15

    assert Validator.parse_and_validate!(param, "query", name, nil) == nil
  end

  test "simple type number" do
    param = %{
      "required" => true,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{"type" => "number"}
      }
    }

    name = "test_float"
    assert Validator.parse_and_validate!(param, "path", name, "10") == 10.0

    assert_raise Oasis.BadRequestError,
                 ~r/Failed to convert parameter/,
                 fn ->
                   Validator.parse_and_validate!(param, "path", name, "10.0xyz")
                 end

    assert Validator.parse_and_validate!(param, "path", name, "10.001") == 10.001
  end

  test "simple type string" do
    param = %{
      "required" => true,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{"type" => "string", "minLength" => 3, "maxLength" => 6}
      }
    }

    name = "test_str"

    assert_raise Oasis.BadRequestError,
                 ~r/Expected value to have a minimum length of 3 but was 1/,
                 fn ->
                   Validator.parse_and_validate!(param, "header", name, "a")
                 end

    assert Validator.parse_and_validate!(param, "header", name, "abcdef") == "abcdef"
  end

  test "simple type string format" do
    param = %{
      "required" => true,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{
          "type" => "string",
          "pattern" => "^(\\([0-9]{3}\\))?[0-9]{3}-[0-9]{4}$",
          "maxLength" => 12
        }
      }
    }

    name = "test_str"
    assert Validator.parse_and_validate!(param, "header", name, "555-1212") == "555-1212"

    assert_raise Oasis.BadRequestError,
                 ~r/Expected value to have a maximum length of 12 but was 13/,
                 fn ->
                   Validator.parse_and_validate!(param, "header", name, "(888)555-1212")
                 end

    assert_raise Oasis.BadRequestError, ~r/Does not match pattern/, fn ->
      Validator.parse_and_validate!(param, "header", name, "(800)FLOWERS")
    end

    param = %{
      "required" => true,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{
          "type" => "string",
          "format" => "email"
        }
      }
    }

    assert Validator.parse_and_validate!(param, "header", name, "test@test.com") ==
             "test@test.com"

    assert_raise Oasis.BadRequestError, ~r/Expected to be a valid email/, fn ->
      Validator.parse_and_validate!(param, "header", name, "test")
    end

    assert_raise Oasis.BadRequestError, ~r/Expected to be a valid email/, fn ->
      Validator.parse_and_validate!(param, "header", name, "test@test")
    end
  end

  test "simple type string enum" do
    param = %{
      "required" => true,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{
          "type" => "string",
          "enum" => ["A", "B", "C"]
        }
      }
    }

    name = "test_enum"
    Validator.parse_and_validate!(param, "path", name, "A")

    assert_raise Oasis.BadRequestError, ~r/Value is not allowed in enum/, fn ->
      Validator.parse_and_validate!(param, "path", name, "D")
    end
  end

  test "simple type boolean" do
    param = %{
      "required" => true,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{
          "type" => "boolean"
        }
      }
    }

    name = "test_str"

    assert Validator.parse_and_validate!(param, "header", name, "true") == true
    assert Validator.parse_and_validate!(param, "header", name, "false") == false

    assert_raise Oasis.BadRequestError, ~r/Expected Boolean but got String/, fn ->
      Validator.parse_and_validate!(param, "header", name, "True")
    end

    assert_raise Oasis.BadRequestError, ~r/Expected Boolean but got Integer/, fn ->
      Validator.parse_and_validate!(param, "path", name, 0)
    end
  end

  test "simple type null" do
    param = %{
      "required" => false,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{
          "type" => "null"
        }
      }
    }

    name = "test_null"
    assert Validator.parse_and_validate!(param, "cookie", name, nil) == nil

    assert_raise Oasis.BadRequestError, ~r/Type mismatch. Expected Null but got String/, fn ->
      Validator.parse_and_validate!(param, "cookie", name, "1")
    end
  end

  test "type array items" do
    param = %{
      "required" => true,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{
          "type" => "array",
          "items" => %{
            "type" => "integer"
          }
        }
      }
    }

    name = "test_array"
    data = [1, 2, 3]
    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "header", name, input) == data
  end

  test "type array tuple validation" do
    param = %{
      "required" => true,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{
          "type" => "array",
          "items" => [
            %{
              "type" => "integer"
            },
            %{
              "type" => "string"
            },
            %{
              "type" => "string",
              "enum" => ["Street", "Avenue", "Boulevard"]
            },
            %{
              "type" => "string",
              "enum" => ["NW", "NE", "SW", "SE"]
            }
          ],
          "additionalItems" => true
        }
      }
    }

    name = "test_array"
    data = [1600, "Pennsylvania", "Avenue", "NW"]
    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "header", name, input) == data

    data = [10, "Downing", "Street"]
    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "header", name, input) == data

    data = [1600, "Pennsylvania", "Avenue", "NW", "Washington"]
    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "path", name, input) == data

    data = ["a", "b", "c", "Sussex", "Drive"]
    input = Jason.encode!(data)

    assert_raise Oasis.BadRequestError, ~r/Type mismatch. Expected Integer but got String/, fn ->
      Validator.parse_and_validate!(param, "query", name, input)
    end

    data = [1600, "Pennsylvania", "Avenue", "NW", "Washington"]
    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "query", name, input) == data

    param = %{
      "required" => true,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{
          "type" => "array",
          "items" => [
            %{
              "type" => "integer"
            },
            %{
              "type" => "string"
            },
            %{
              "type" => "string",
              "enum" => ["Street", "Avenue", "Boulevard"]
            },
            %{
              "type" => "string",
              "enum" => ["NW", "NE", "SW", "SE"]
            }
          ],
          "additionalItems" => %{"type" => "string"}
        }
      }
    }

    name = "test_array"
    data = [1600, "Pennsylvania", "Avenue", "NW", "Washington"]
    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "query", name, input) == data

    data = [1600, "Pennsylvania", "Avenue", "NW", 1000]
    input = Jason.encode!(data)

    assert_raise Oasis.BadRequestError, ~r/Type mismatch. Expected String but got Integer/, fn ->
      Validator.parse_and_validate!(param, "query", name, input)
    end

    param = %{
      "required" => false,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{
          "type" => "array",
          "minItems" => 2,
          "maxItems" => 3
        }
      }
    }

    name = "test_name"
    data = []
    input = Jason.encode!(data)

    assert_raise Oasis.BadRequestError, ~r/Expected a minimum of 2 items but got 0/, fn ->
      Validator.parse_and_validate!(param, "query", name, input)
    end

    data = [1, 2]
    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "query", name, input) == data

    data = [3, 2, 1]
    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "query", name, input) == data

    data = [1, 2, 3, 4, 5]
    input = Jason.encode!(data)

    assert_raise Oasis.BadRequestError, ~r/Expected a maximum of 3 items but got 5/, fn ->
      Validator.parse_and_validate!(param, "query", name, input)
    end

    param = %{
      "required" => false,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{
          "type" => "array",
          "uniqueItems" => true,
          "items" => %{
            "type" => "integer"
          }
        }
      }
    }

    name = "test_name"
    data = [1, 2, 3, 4]
    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "query", name, input) == data

    data = [1, 2, 3, 2, 4]
    input = Jason.encode!(data)

    assert_raise Oasis.BadRequestError, ~r/Expected items to be unique but they were not/, fn ->
      Validator.parse_and_validate!(param, "query", name, input)
    end
  end

  test "type object properties" do
    param = %{
      "required" => true,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{
          "type" => "object",
          "properties" => %{
            "number" => %{"type" => "number"},
            "street_name" => %{"type" => "string"},
            "street_type" => %{
              "type" => "string",
              "enum" => ["Street", "Avenue", "Boulevard"]
            }
          }
        }
      }
    }

    name = "test_array"
    data = %{"number" => 100}
    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "query", name, input) == data

    data = %{"number" => 100, "street_name" => "abc", "street_type" => "Avenue"}
    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "query", name, input) == data

    data = %{
      "number" => 100,
      "street_name" => "abc",
      "street_type" => "Avenue",
      "addition" => 2021
    }

    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "query", name, input) == data

    data = %{"number" => "100", "street_name" => "abc", "street_type" => 1}
    input = Jason.encode!(data)

    assert_raise Oasis.BadRequestError, ~r/Type mismatch. Expected Number but got String/, fn ->
      Validator.parse_and_validate!(param, "query", name, input)
    end
  end

  test "type object required properties" do
    param = %{
      "required" => true,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{
          "type" => "object",
          "properties" => %{
            "number" => %{"type" => "number"},
            "street_name" => %{"type" => "string"},
            "street_type" => %{
              "type" => "string",
              "enum" => ["Street", "Avenue", "Boulevard"]
            }
          },
          "required" => ["number", "street_name"]
        }
      }
    }

    name = "test_array"
    data = %{"number" => 1, "street_type" => "Street"}
    input = Jason.encode!(data)

    assert_raise Oasis.BadRequestError, ~r/Required property street_name was not present/, fn ->
      Validator.parse_and_validate!(param, "query", name, input)
    end

    data = %{"number" => 1, "street_name" => "test street name"}
    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "query", name, input) == data
  end

  test "type object property dependencies" do
    schema = %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string"},
        "credit_card" => %{"type" => "number"},
        "billing_address" => %{"type" => "string"}
      },
      "required" => ["name"],
      "dependencies" => %{
        "credit_card" => ["billing_address"],
        "billing_address" => ["credit_card"]
      }
    }

    param = %{
      "required" => true,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: schema
      }
    }

    name = "test"

    data = %{
      "name" => "test_name",
      "credit_card" => 111_111_111_111,
      "billing_address" => "100 street"
    }

    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "query", name, input) == data

    data = %{
      "name" => "test_name"
    }

    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "query", name, input) == data

    data = %{
      "name" => "test_name",
      "credit_card" => 111_111_111_111
    }

    input = Jason.encode!(data)

    assert_raise Oasis.BadRequestError,
                 ~r/Property credit_card depends on property billing_address to be present but it was not/,
                 fn ->
                   Validator.parse_and_validate!(param, "query", name, input)
                 end

    data = %{
      "name" => "test_name",
      "billing_address" => "100 street"
    }

    input = Jason.encode!(data)

    assert_raise Oasis.BadRequestError,
                 ~r/Property billing_address depends on property credit_card to be present but it was not/,
                 fn ->
                   Validator.parse_and_validate!(param, "query", name, input)
                 end
  end

  test "type object pattern properties" do
    schema = %{
      "type" => "object",
      "patternProperties" => %{
        "^S_" => %{"type" => "string"},
        "^I_" => %{"type" => "integer"}
      },
      "properties" => %{},
      "additionalProperties" => false
    }

    param = %{
      "required" => true,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: schema
      }
    }

    name = "test"
    data = %{"S_25" => "test string"}
    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "query", name, input) == data

    data = %{"I_0" => 0}
    input = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "query", name, input) == data

    data = %{"S_0" => 0}
    input = Jason.encode!(data)

    assert_raise Oasis.BadRequestError, ~r/Type mismatch. Expected String but got Integer/, fn ->
      Validator.parse_and_validate!(param, "query", name, input)
    end

    data = %{"I_1" => "1"}
    input = Jason.encode!(data)

    assert_raise Oasis.BadRequestError, ~r/Type mismatch. Expected Integer but got String/, fn ->
      Validator.parse_and_validate!(param, "query", name, input)
    end

    schema = %{
      "type" => "object",
      "patternProperties" => %{
        "^S_" => %{"type" => "string"},
        "^I_" => %{"type" => "integer"}
      },
      "properties" => %{"builtin" => %{"type" => "integer"}},
      "additionalProperties" => %{"type" => "string"}
    }

    param = %{
      "required" => true,
      "schema" => %ExJsonSchema.Schema.Root{
        schema: schema
      }
    }

    data = %{"builtin" => 1}
    name = "test"
    value = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "query", name, value) == data

    data = %{"I_25" => 0, "builtin" => 1}
    value = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "query", name, value) == data

    data = %{"I_25" => 0, "builtin" => 1, "otherfield" => "string"}
    value = Jason.encode!(data)
    assert Validator.parse_and_validate!(param, "query", name, value) == data

    data = %{"S_25" => 0, "builtin" => 1, "otherfield" => "string"}
    value = Jason.encode!(data)

    assert_raise Oasis.BadRequestError, ~r/Type mismatch. Expected String but got Integer/, fn ->
      Validator.parse_and_validate!(param, "query", name, value) == data
    end

    data = %{"I_25" => 0, "builtin" => 1, "otherfield" => 1}
    value = Jason.encode!(data)

    assert_raise Oasis.BadRequestError, ~r/Type mismatch. Expected String but got Integer/, fn ->
      Validator.parse_and_validate!(param, "query", name, value)
    end

    data = %{"otherfield" => 1}
    value = Jason.encode!(data)

    assert_raise Oasis.BadRequestError, ~r/Type mismatch. Expected String but got Integer/, fn ->
      Validator.parse_and_validate!(param, "query", name, value)
    end
  end

  test "content type application/vnd.github+json" do
    param = %{
      "required" => true,
      "content" => %{
        "application/vnd.github+json" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{
              "properties" => %{
                "name" => %{"type" => "number"},
                "tag" => %{"type" => "number"}
              },
              "required" => ["lat", "long"],
              "type" => "object"
            }
          }
        }
      }
    }

    name = "local"
    data = %{"lat" => 12.01, "long" => 93.1}
    formatted = Validator.parse_and_validate!(param, "header", name, Jason.encode!(data))
    assert formatted == data

    data = %{"lat" => 43.21}

    assert_raise Oasis.BadRequestError, ~r/Required property long was not present./, fn ->
      Validator.parse_and_validate!(param, "header", name, Jason.encode!(data))
    end
  end

  test "content type application/xml" do
    # Currently, DO NOT process application/xml
    param = %{
      "required" => true,
      "content" => %{
        "application/xml" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{
              "properties" => %{
                "id" => %{"type" => "integer"},
                "title" => %{"type" => "string"},
                "author" => %{"type" => "string"}
              },
              "required" => ["id", "title", "author"],
              "type" => "object"
            }
          }
        }
      }
    }

    name = "book"
    data = "<book><id>0</id><title>str</title><author>str</author></book>"

    formatted = Validator.parse_and_validate!(param, "header", name, data)
    assert formatted == data

    # no validation to unexpected `id` value
    data = "<book><id>str</id><title>str</title><author>str</author></book>"
    formatted = Validator.parse_and_validate!(param, "header", name, data)
    assert formatted == data
  end

  test "content text/plain" do
    param = %{
      "required" => true,
      "content" => %{
        "text/plain" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{
              "type" => "array",
              "items" => %{
                "type" => "string"
              }
            }
          }
        }
      }
    }

    name = "test_name"
    data = ["1", "2", "3"]
    input = Jason.encode!(data)
    formatted_value = Validator.parse_and_validate!(param, "query", name, input)

    assert formatted_value == data
  end

  test "content text/plain; charset=utf-8" do
    param = %{
      "required" => true,
      "content" => %{
        "text/plain; charset=utf-8" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{
              "type" => "array",
              "items" => %{
                "type" => "integer"
              }
            }
          }
        }
      }
    }

    name = "test_name"
    data = [1, 2, 3]
    input = Jason.encode!(data)
    formatted_value = Validator.parse_and_validate!(param, "query", name, input)

    assert formatted_value == data
  end

  test "content image/png" do
    param = %{
      "content" => %{
        "image/png" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{
              "type" => "string",
              "contentMediaType" => "image/png",
              "contentEncoding" => "base64"
            }
          }
        }
      }
    }

    name = "image"
    input = "image_binary"
    formatted_value = Validator.parse_and_validate!(param, "query", name, input)
    assert input == formatted_value
  end

  test "invalid json" do
    param = %{
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{
          "type" => "array",
          "items" => %{
            "type" => "string"
          }
        }
      }
    }

    name = "name"
    input = "invalid_json"

    assert_raise Oasis.BadRequestError,
                 ~r/Failed to convert parameter/,
                 fn ->
                   Validator.parse_and_validate!(param, "query", name, input)
                 end
  end

  test "unknown schema type to be ignored" do
    param = %{
      "schema" => %ExJsonSchema.Schema.Root{
        schema: %{
          "type" => "UNKNOWN_JSON_SCHEMA"
        }
      }
    }

    name = "test_param"
    input = "input_str"

    # for ex_json_schema 0.7.4
    assert_raise CaseClauseError, ~r/no case clause matching: "UNKNOWN_JSON_SCHEMA"/, fn ->
      Validator.parse_and_validate!(param, "query", name, input)
    end

    # for ex_json_schema 0.8.0-rc1
    #assert_raise FunctionClauseError, ~r/no function clause matching/, fn ->
    #  Validator.parse_and_validate!(param, "query", name, input)
    #end
  end

  test "parse urlencoded" do
    param = %{
      "content" => %{
        "application/x-www-form-urlencoded" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            custom_format_validator: nil,
            location: :root,
            refs: %{},
            schema: %{
              "properties" => %{
                "fav_number" => %{"type" => "integer"},
                "name" => %{"type" => "string"}
              },
              "required" => ["name", "fav_number"],
              "type" => "object"
            }
          }
        }
      },
      "required" => true
    }

    input = %{"key" => "value"}

    assert_raise Oasis.BadRequestError,
                 ~r/Required properties name, fav_number were not present./,
                 fn ->
                   Validator.parse_and_validate!(param, "body", "body_request", input)
                 end

    input = %{"fav_number" => 1, "name" => "test_name"}
    result = Validator.parse_and_validate!(param, "body", "body_request", input)
    assert result == %{"fav_number" => 1, "name" => "test_name"}
  end

  test "invalid definition to be ignored" do
    param = %{"required" => true}

    input = "value"
    name = "username"
    assert Validator.parse_and_validate!(param, "query", name, input) == input

    input = Jason.encode(%{"a" => 1, "b" => 2})
    assert Validator.parse_and_validate!(param, "query", name, input) == input
  end

  test "parse empty map" do
    type = %{
      "content" => %{
        "application/json" => %{
          "schema" => %ExJsonSchema.Schema.Root{
            schema: %{
              "properties" => %{"refresh_token" => %{"type" => "string"}},
              "required" => ["refresh_token"],
              "type" => "object"
            }
          }
        }
      },
      "required" => true
    }
    assert_raise Oasis.BadRequestError,
                 ~r/Required property refresh_token was not present/,
                 fn ->
                   Validator.parse_and_validate!(type, "body", "requestBody", %{})
                 end
  end

end
