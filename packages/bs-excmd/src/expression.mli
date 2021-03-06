open AST

(** Most of these methods take their names from standard OCaml methods over maps. cf.
    {{:https://reasonml.github.io/api/Map.Make.html} [Map.Make]}.

    (An important aspect of the behaviour of this API is the {{!reso} resolution of
    ambiguous words} in parsed commands. See more details at the bottom of this file.) *)

type t
(** An alias to {!AST.expression}, abstracted that mutation may be controlled. *)

type flag_payload = Empty | Payload of AST.word

(** {2 Basic getters} *)

(** None of these may mutate the data-structure. *)

val count : t -> int

val command : t -> AST.word

val mem : string -> t -> bool
(** [mem fl expr] returns [true] if [expr] contains flag [fl], [false] otherwise.

    Notably, this {e does not} {{!reso} resolve} any unresolved words from the parsed
    expression. *)

val is_resolved : string -> t -> bool
(** [is_resolved fl expr] returns [true] if [expr] contains a flag [fl] {e and} the last
    such flag [fl] is already {{!reso} resolved}; and [false] otherwise. *)

val has_payload : string -> t -> bool
(** [has_payload fl expr] returns [true] if [expr] contains a flag [fl], the last such
    flag [fl] is already {{!reso} resolved}, {e and} that last flag [fl] resolved to a
    [string] payload instead of a [bool]. Returns [false] otherwise. *)

val flags : t -> string list
(** [flags expr] returns a list of the flags used in [expr], including only the {e names}
    of flags - not the payloads. *)

(** {2 Resolvers (mutative getters)} *)

(** All of these may, in some circumstances, mutate the data-structure. *)

val positionals : t -> AST.word list
(** [positionals expr] returns a [list] of positional (non-flag) arguments in [expr].

    This {{!reso} fully resolves} [expr] — any ambiguous words will be consumed as
    positional arguments, becoming unavailable as flag-payloads. *)

val iter : (string -> flag_payload -> unit) -> t -> unit
(** [iter f expr] applies [f] to all flags in expression [expr]. [f] receives the flag as
    its first argument, and the associated, fully-{{!reso} resolved} value as the second
    argument.

    This {{!reso} fully resolves} [expr] — any ambiguous words will be consumed as the
    values to their associated flags, becoming unavailable as positional arguments. *)

val iteri : (int -> string -> flag_payload -> unit) -> t -> unit
(** [iteri f expr], as with {!iter}, applies [f] to each flag in [expr]. However, [f] will
    also receive the {e index} of each flag as an argument. *)

val rev_iteri : (int -> string -> flag_payload -> unit) -> t -> unit
(** [rev_iteri f expr], as with {!iteri}, applies [f] to each flag in [expr]; except that
    the flags are observed in reverse order — from the end of the expression, to the
    start. (This is marginally more efficient than either {!iter} or {!iteri}.) *)

val flag : string -> t -> flag_payload option
(** [flag fl expr] finds a flag by the name of [fl], {{!reso} resolves} it if necessary,
    and produces the payload there of, if any.

    This can yield ...

    - [None], indicating flag [fl] was not present at all.
    - [Some Empty], indicating a flag [fl] was present, but the last such resolved to
      having no payload.
    - [Some (Payload word)], indicating a flag [fl] was present and the last such became
      resolved to the payload [word]. This can involve resolution of the word immediately
      following said [fl], removing it from the implicit [positionals]. *)

(** {2 Other helpers} *)

val pp : t -> unit
(** Pretty-print a {{!type:t} expression}. Implementation varies between platforms. *)

val hydrate : t -> AST.expression
(** Type-converter between abstract {!Expression.t} and concrete {!type:AST.expression}.

    Careful; the operations in this module are intended to maintain safe invariants,
    consuming components of a [expression] in reasonable ways. You must not devolve one
    into a raw {!AST} node, modify it unsafely, and then expect to continue to use the
    functions in this module. *)

val from_script : AST.t -> t array

(** {2:reso Note: Resolution of ambiguous words}

    It's important to note that a expression is a mutable structure, and that accesses
    intentionally mutate that structure — in particular, a given word in the original
    parsed string can only be {e either} a positional argument {e or} the argument to a
    preceding flag.

    Any function that accesses either the {e value} of a flag, or accesses the
    {!positionals} at all, is going to “resolve” that word in the original source. If
    the word was ambiguously positioned,
    {e that access will result in the datastructure changing} — to prevent the word
    later becoming resolved in an incompatible way.

    For example: given the following input command as a {!Expression.t},

    {[ hello -- where world ]}

    ... there's two possible ways to interpret the ['world'], chosen between by the order
    in which you invoke either {!positionals}, or flag-value-reading functions (like
    {!iter} or {!find}/{!flag}):

    {[
       (* Yields zero positionals, and 'world' as the value associated with the flag '--where'. *)
       let expr1 = Parser.expression_of_string "hello --where world" in
       let where = Expression.flag "where" expr1 (* Some (Payload 'world') *) in
       let xs = Expression.positionals expr1 (* [] *)

       (* Yields one positional, 'world', and no value associated with the flag '--where'. *)
       let expr2 = Parser.expression_of_string "hello --where world" in
       let xs = Expression.positionals expr2 (* ['world'] *) in
       let where = Expression.flag "where" expr2 (* Some (Empty) *)
    ]}

    Once any ambiguous words have been so resolved (or when a function is called that
    inherently resolves {e all} ambiguous words, such as {!positionals} or {!iter}), a
    {!Expression.t} is considered “fully resolved.” No functions in this module will
    further mutate such a [expression]. *)

(**/**)

val payload_to_opt : flag_payload -> AST.word option
(** Helper to convert a [flag_payload] to a BuckleScript-friendly [option]. *)

val flags_arr : t -> string array

val positionals_arr : t -> AST.word array

val dehydrate : AST.expression -> t
