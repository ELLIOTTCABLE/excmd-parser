(** {2 Describing structures}

    Some of our data-structures provide conversion functions to produce alternative
    formats of themselves. These are automatically generated at compile-time by
    {{:https://ocamlverse.github.io/content/ppx.html} PPX preprocessors} in OCaml.

    Unfortunately, we use different data-structures per compile-target: in native OCaml,
    we use [{{:https://github.com/ocaml-ppx/ppx_deriving_yojson} ppx_deriving_yojson}] to
    produce a value of type
    {{:https://mjambon.github.io/mjambon2016/yojson-doc/Yojson.Basic.html#TYPEjson}
    [Yojson.Basic.json]}; but when being compiled to JavaScript, we use BuckleScript's
    {{:https://bucklescript.github.io/docs/en/generate-converters-accessors.html#convert-between-jst-object-and-record}
    [jsConverter]} tooling to generate the built-in
    {{:https://bucklescript.github.io/bucklescript/api/Js.html#TYPEt} [Js.t]} type. These
    generators also produce functions of different names: {!to_yojson} is available on
    the native side, and {!tToJs} on the BuckleScript side.

    Due to the fact that the relevant types differ between platforms, fully generic code
    involving alternative-format representations like the above isn't clean and easy.
    Both of the above flavours of conversion-function will raise a runtime exception if
    called on a platform that doesn't support them; if you need to, you can catch said
    exception and swap implementations based on that. *)

exception WrongPlatform of [ `Native | `JavaScript ] * string

(* These are initially declared as runtime errors, so they can be shadowed by the 'valid'
   functions generated by the below ppxes. *)
let unavailable_on target name = raise (WrongPlatform (target, name))

let tOfJs _ = unavailable_on `Native "tOfJs"

let tToJs _ = unavailable_on `Native "tToJs"

let expressionOfJs _ = unavailable_on `Native "expressionOfJs"

let expressionToJs _ = unavailable_on `Native "expressionToJs"

let to_yojson _ = unavailable_on `JavaScript "to_yojson"

let of_yojson _ = unavailable_on `JavaScript "of_yojson"

let expression_to_yojson _ = unavailable_on `JavaScript "expression_to_yojson"

let expression_of_yojson _ = unavailable_on `JavaScript "expression_of_yojson"

type 'a unresolved = Unresolved | Resolved of 'a | Absent
[@@bs.deriving jsConverter] [@@deriving to_yojson { optional = true }]

type 'a or_subexpr = Sub of expression | Literal of 'a
[@@bs.deriving jsConverter] [@@deriving to_yojson { optional = true }]

and flag = { name : string; mutable payload : string or_subexpr unresolved }
[@@bs.deriving jsConverter] [@@deriving to_yojson { optional = true }]

and arg = Positional of string or_subexpr | Flag of flag
[@@bs.deriving jsConverter] [@@deriving to_yojson { optional = true }]

and expression = { count : int; cmd : string or_subexpr; mutable rev_args : arg list }
[@@bs.deriving jsConverter] [@@deriving to_yojson { optional = true }]

type t = { expressions : expression array }
[@@bs.deriving jsConverter] [@@deriving to_yojson { optional = true }]

let make_expression ?count ~cmd ~rev_args =
   { count =
        ( match count with
          | Some c -> int_of_string c
          | None -> 1 )
   ; cmd
   ; rev_args
   }


let rec copy_string_or_subexpr sos =
   match sos with
    | Literal str -> Literal (String.copy str)
    | Sub expr -> Sub (copy_expression expr)


and copy_flag flg =
   { flg with
      payload =
         ( match flg.payload with
           | Unresolved -> Unresolved
           | Resolved v -> Resolved (copy_string_or_subexpr v)
           | Absent -> Absent )
   }


and copy_arg arg =
   match arg with
    | Positional sos -> Positional (copy_string_or_subexpr sos)
    | Flag flg -> Flag (copy_flag flg)


and copy_expression expr =
   { expr with
      cmd = copy_string_or_subexpr expr.cmd
    ; rev_args = List.map copy_arg expr.rev_args
   }


let copy ast = { expressions = Array.map copy_expression ast.expressions }

let pp_bs ast =
   let obj = tToJs ast in
   Js.Json.stringifyAny obj |> Js.log


let pp_native ast =
   let json = to_yojson ast in
   let out = Format.formatter_of_out_channel stdout in
   Yojson.Safe.pretty_print out json


let pp ast = try pp_bs ast with WrongPlatform (`Native, _) -> pp_native ast

let pp_expression_bs expr =
   let obj = expressionToJs expr in
   Js.Json.stringifyAny obj |> Js.log


let pp_expression_native expr =
   let json = expression_to_yojson expr in
   let out = Format.formatter_of_out_channel stdout in
   Yojson.Safe.pretty_print out json


let pp_expression ast =
   try pp_expression_bs ast with WrongPlatform (`Native, _) -> pp_expression_native ast


(**/**)

let is_literal = function
   | Literal _ -> true
   | Sub _ -> false


let get_literal_exn = function
   | Literal x -> x
   | Sub _ -> raise Not_found


let get_sub_exn = function
   | Literal _ -> raise Not_found
   | Sub x -> x
