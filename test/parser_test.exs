defmodule Oasis.ParserTest do
  use ExUnit.Case

  import Oasis.Parser

  @type_integer %{"type" => "integer"}
  @type_string %{"type" => "string"}
  @type_null %{"type" => "null"}
  @type_boolean %{"type" => "boolean"}
  @type_number %{"type" => "number"}

  test "parse string" do
    assert parse(@type_string, "1") == "1"
    assert parse(@type_string, 1) == 1
    assert parse(@type_string, "98.7654") == "98.7654"
    assert parse(@type_string, 98.7654) == 98.7654
    assert parse(@type_string, "hello") == "hello"
  end

  test "parse integer" do
    assert parse(@type_integer, "1") == 1
    assert parse(@type_integer, 1) == 1
    assert parse(@type_integer, "-1") == -1
    assert parse(@type_integer, -1) == -1

    assert_raise ArgumentError, ~r/argument error/, fn ->
      parse(@type_integer, "1.2")
    end

    assert_raise ArgumentError, ~r/argument error/, fn ->
      parse(@type_integer, "a")
    end
  end

  test "parse number" do
    assert parse(@type_number, "1") == 1.0
    assert parse(@type_number, 1) == 1
    assert parse(@type_number, "1.0") == 1.0
    assert parse(@type_number, 1.0) == 1.0
    assert parse(@type_number, "1.000") == 1.0
    assert parse(@type_number, 1.000) == 1.0
    assert parse(@type_number, "12.345") == 12.345
    assert parse(@type_number, 12.345) == 12.345
    assert parse(@type_number, "100.001") == 100.001
    assert parse(@type_number, 100.001) == 100.001
    assert parse(@type_number, "100") == 100.0
    assert parse(@type_number, 100) == 100.0
  end

  test "parse null" do
    assert parse(@type_null, nil) == nil
    assert parse(@type_null, "1") == "1"
    assert parse(@type_null, false) == false
    assert parse(@type_null, true) == true
    assert parse(@type_null, "string") == "string"
  end

  test "parse boolean" do
    assert parse(@type_boolean, "true") == true
    assert parse(@type_boolean, true) == true
    assert parse(@type_boolean, "True") == "True"
    assert parse(@type_boolean, "false") == false
    assert parse(@type_boolean, false) == false
    assert parse(@type_boolean, "False") == "False"
    assert parse(@type_boolean, "1") == "1"
    assert parse(@type_boolean, 1) == 1
    assert parse(@type_boolean, "0") == "0"
    assert parse(@type_boolean, 0) == 0
    assert parse(@type_boolean, "unknown") == "unknown"
  end

  test "parse simple array" do
    type = %{
      "type" => "array",
      "items" => %{
        "type" => "number"
      }
    }

    assert parse(type, ["1", "2", "3"]) == [1.0, 2.0, 3.0]
    assert parse(type, ["11.1", "2.22", "33.333"]) == [11.1, 2.22, 33.333]

    assert_raise ArgumentError, ~r/argument error/, fn ->
      parse(type, ["a", "2", "c"])
    end

    type = %{
      "type" => "array",
      "items" => [
        %{
          "type" => "integer"
        },
        %{
          "type" => "string"
        },
        %{
          "type" => "number"
        }
      ]
    }

    assert parse(type, ["1", "a", "9"]) == [1, "a", 9.0]
    assert parse(type, ["100", "1", "0.99"]) == [100, "1", 0.99]

    # if non-string input will ignore parse
    assert parse(type, [1, "a", 9.0]) == [1, "a", 9.0]

    assert_raise ArgumentError, ~r/argument error/, fn ->
      parse(type, ["1", "a", "9", "9"])
    end

    assert_raise ArgumentError, ~r/argument error/, fn ->
      parse(type, ["a", "a", "9"])
    end

    # no "items" defined to parse
    type = %{
      "type" => "array",
      "minItems" => 2,
      "maxItems" => 3
    }

    assert parse(type, ["1", "2", "3"]) == ["1", "2", "3"]
    assert parse(type, ["1"]) == ["1"]
    assert parse(type, ["1", "2", "3", "4", "5"]) == ["1", "2", "3", "4", "5"]

    type = %{
      "type" => "array",
      "uniqueItems" => true
    }

    assert parse(type, ["a", "a", "b"]) == ["a", "a", "b"]
    assert parse(type, ["1"]) == ["1"]
  end

  test "parse simple object" do
    type = %{
      "type" => "object",
      "properties" => %{
        "number" => @type_number,
        "street_name" => @type_string,
        "street_type" => @type_string,
        "flag" => @type_boolean
      }
    }

    input = %{"number" => "1600", "street_name" => "hello", "flag" => "true"}
    expected = %{"number" => 1600, "street_name" => "hello", "flag" => true}
    assert parse(type, input) == expected

    input = Jason.encode!(expected)
    assert parse(type, input) == expected

    assert_raise ArgumentError, ~r/argument error/, fn ->
      parse(type, "invalid")
    end

    type = %{
      "type" => "object",
      "properties" => %{
        "number" => @type_number,
        "street_name" => @type_string,
        "street_type" => @type_string,
        "flag" => @type_boolean
      },
      "additionalProperties" => false
    }

    # ignore `add` field sinece `additionalProperties: false`
    input = %{"number" => "1600", "street_name" => "hello", "flag" => "true", "add" => "added1"}

    assert parse(type, input) == %{
             "number" => 1600,
             "street_name" => "hello",
             "flag" => true,
             "add" => "added1"
           }

    input = %{"number" => "1600", "street_name" => "hello", "flag" => "true", "add" => 1}

    assert parse(type, input) == %{
             "number" => 1600,
             "street_name" => "hello",
             "flag" => true,
             "add" => 1
           }

    type = %{
      "type" => "object",
      "properties" => %{
        "number" => @type_number,
        "street_name" => @type_string,
        "street_type" => @type_string,
        "flag" => @type_boolean
      },
      "additionalProperties" => %{"type" => "integer"}
    }

    # process additional properties
    input = %{
      "number" => "1600",
      "street_name" => "hello",
      "flag" => "true",
      "add" => "100",
      "add2" => "-1"
    }

    assert parse(type, input) == %{
             "number" => 1600,
             "street_name" => "hello",
             "flag" => true,
             "add" => 100,
             "add2" => -1
           }

    input = %{"number" => "1600", "street_name" => "hello", "flag" => "true"}
    assert parse(type, input) == %{"number" => 1600, "street_name" => "hello", "flag" => true}

    input = %{"number" => "1600", "street_name" => "hello", "flag" => "true"}
    assert parse(type, input) == %{"number" => 1600, "street_name" => "hello", "flag" => true}

    assert_raise ArgumentError, ~r/argument error/, fn ->
      input = %{"number" => "1600", "street_name" => "hello", "flag" => "true", "loc" => "12.3a"}
      parse(type, input) == %{"number" => 1600, "street_name" => "hello", "flag" => true}
    end

    # no "properties" defined to parse
    type = %{
      "type" => "object",
      "minProperties" => 2,
      "maxProperties" => 3
    }

    input = %{"tmp" => "1"}
    assert parse(type, input) == input
  end

  test "parse object with dependencies" do
    # property dependencies
    type = %{
      "type" => "object",
      "properties" => %{
        "name" => @type_string,
        "credit_card" => @type_integer,
        "billing_address" => @type_string
      },
      "dependencies" => %{
        "credit_card" => ["billing_address"]
      }
    }

    # only parse existed fields, do not validate in parse.
    input = %{"name" => "testname", "credit_card" => "123"}
    assert parse(type, input) == %{"name" => "testname", "credit_card" => 123}

    input = %{"name" => "testname", "credit_card" => "123", "unknown" => "unknown"}

    assert parse(type, input) == %{
             "name" => "testname",
             "credit_card" => 123,
             "unknown" => "unknown"
           }

    input = %{
      "name" => "testname",
      "credit_card" => "123",
      "billing_address" => "billing_address 123"
    }

    assert parse(type, input) == %{
             "name" => "testname",
             "credit_card" => 123,
             "billing_address" => "billing_address 123"
           }

    # schema dependencies
    type = %{
      "type" => "object",
      "properties" => %{
        "name" => @type_string,
        "credit_card" => @type_integer
      },
      "dependencies" => %{
        "credit_card" => %{
          "properties" => %{
            "billing_address" => @type_string,
            "added_number" => @type_integer
          },
          "required" => ["billing_address"]
        }
      }
    }

    input = %{
      "name" => "testname",
      "credit_card" => "123",
      "billing_address" => "billing_address 123",
      "added_number" => "0504"
    }

    assert parse(type, input) == %{
             "name" => "testname",
             "credit_card" => 123,
             "billing_address" => "billing_address 123",
             "added_number" => 504
           }
  end

  test "parse object with array" do
    type = %{
      "type" => "object",
      "properties" => %{
        "name" => @type_string,
        "credit_card" => @type_integer,
        "options" => %{
          "type" => "array",
          "items" => @type_integer
        }
      }
    }

    input = %{"name" => "Test", "credit_card" => "456", "options" => ["1", "2", "3"]}
    assert parse(type, input) == %{"name" => "Test", "credit_card" => 456, "options" => [1, 2, 3]}

    type = %{
      "type" => "object",
      "properties" => %{
        "name" => @type_string,
        "credit_card" => @type_integer,
        "options" => %{
          "type" => "array",
          "items" => [
            @type_string,
            @type_number,
            %{
              "type" => "object",
              "properties" => %{
                "field1" => @type_number,
                "field2" => @type_boolean,
                "field3" => @type_string
              }
            }
          ]
        }
      }
    }

    input = %{
      "name" => "Test",
      "credit_card" => "456",
      "options" => [
        "abc",
        "89.98",
        %{
          "field1" => "90",
          "field2" => "false",
          "field3" => "inner_test"
        }
      ]
    }

    assert parse(type, input) == %{
             "name" => "Test",
             "credit_card" => 456,
             "options" => [
               "abc",
               89.98,
               %{
                 "field1" => 90.0,
                 "field2" => false,
                 "field3" => "inner_test"
               }
             ]
           }
  end

  test "parse array with object" do
    type = %{
      "type" => "array",
      "items" => [
        @type_integer,
        %{
          "type" => "array",
          "items" => [
            @type_string,
            @type_string
          ]
        },
        %{
          "type" => "array",
          "items" => @type_number
        },
        @type_number
      ]
    }

    input = [
      "1",
      ["a", "b"],
      ["1", "89.1", "0.01"],
      "10"
    ]

    assert parse(type, input) == [1, ["a", "b"], [1.0, 89.1, 0.01], 10.0]

    input = [
      "1",
      ["a", "b"],
      ["1", "89.1", "0.01"]
    ]

    assert_raise ArgumentError, ~r/argument error/, fn ->
      parse(type, input) == [1, ["a", "b"], [1.0, 89.1, 0.01]]
    end
  end

  test "parse object with pattern properties" do
    type = %{
      "type" => "object",
      "properties" => %{
        "builtin" => %{"type" => "number"}
      },
      "patternProperties" => %{
        "^S_" => %{"type" => "string"},
        "^I_" => %{"type" => "integer"}
      },
      "additionalProperties" => @type_string
    }

    input = %{"builtin" => "123"}
    assert parse(type, input) == %{"builtin" => 123.0}

    input = %{"builtin" => "123abc"}

    assert_raise ArgumentError, ~r/argument error/, fn ->
      parse(type, input)
    end

    input = %{"builtin" => "1", "other1" => "v1", "other2" => "10.01"}
    assert parse(type, input) == %{"builtin" => 1.0, "other1" => "v1", "other2" => "10.01"}

    input = %{"builtin" => "1", "S_1" => "str1", "I_1" => "-1", "I_2" => "2"}
    assert parse(type, input) == %{"builtin" => 1.0, "S_1" => "str1", "I_1" => -1, "I_2" => 2}

    input = %{"builtin" => "1", "I_1" => "-10", "other field" => "other"}
    assert parse(type, input) == %{"builtin" => 1.0, "I_1" => -10, "other field" => "other"}

    input = %{"builtin" => "0", "Iunknown" => "abc"}
    assert parse(type, input) == %{"builtin" => 0.0, "Iunknown" => "abc"}

    input = %{"builtin" => "1", "I_2" => "abc"}

    assert_raise ArgumentError, ~r/argument error/, fn ->
      parse(type, input)
    end
  end

  test "parse file upload" do
    type = %{
      "properties" => %{"file" => %{"format" => "binary", "type" => "string"}},
      "type" => "object"
    }

    input = %{
      "file" => %Plug.Upload{
        content_type: "image/png",
        filename: "test.png",
        path: "/var/folders/c3/_tk3ftrx1x71xkz6xhpsxpzr0000gn/T//plug-1620/multipart-1620803361-660920818442426-3"
      }
    }

    assert parse(type, input) == input
  end
end
