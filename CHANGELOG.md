# Changelog

## v0.5.0 (2022-07-21)

* Fix test failed in OTP24
* Add HMAC based authentication implement ([#8](https://github.com/elixir-oasis/oasis/issues/8))
* Some fixing and enhancement ([#12](https://github.com/elixir-oasis/oasis/pull/12))

## v0.4.3 (2021-05-13)

* Fix to make properly handle file uploads

## v0.4.2 (2021-05-11)

* Add `--force` and `--quiet` options for mix oas.gen.plug

## v0.4.1 (2021-04-29)

Fix unexpected "..." string in generated `pre_*` module when a large number of parameters defined

## v0.4.0 (2021-04-14)
* Improve errors handle and add a guide about it

## v0.3.1 (2021-04-08)
* Fix incorrectly handle errors in generated plug module
* Simplify `handle_errors/2` process in generated `pre_*` module

## v0.3.0 (2021-04-08)
* Add `conn.private.oasis_router`
* Add a specification extensions guide
* Support Security Scheme Object with Bearer Authentication
* Fix the order to override `x-oasis-name-space` field

## v0.2.1 (2021-03-24)
* Fix unexpected `:body_schema` in generated `pre_*` module

## v0.2.0 (2021-03-23)
* Use `Oasis.Controller`

## v0.1.0 (2021-03-17)
* Implement some parts of OpenAPI definition `*Object` in parse
* Implement a basic router and plugs pipeline process
* Add a mix task `mix task oas.gen.plug` to generate code
* 100% test coverage
