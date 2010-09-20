(*
 * ocaml-oembed/oembed.mli
 *
 * Copyright (c) 2010 Patrick Walton <pcwalton@mimiga.net>
 *)

(** An implementation of the oEmbed standard for embedding external web content
    on third-party sites. *)

(** Raised when the server sends a response that [parse_response] or [get]
    doesn't understand. *)
exception Malformed

(** Raised when no provider matches the given URL. *)
exception No_provider

(** The type of a URL. *)
type url = string

(** The type of an HTML snippet. *)
type html = string

(** The width and height of an embeddable resource. *)
type dimensions = {
    di_width: int;
    di_height: int;
}

(** The type of an embeddable resource, along with its type-specific info. *)
type resource_type =
| RT_photo of url * dimensions
| RT_video of html * dimensions
| RT_rich of html * dimensions
| RT_link

(** The oEmbed response. *)
type response = {
    re_type: resource_type;
    re_title: string option;
    re_author_name: string option;
    re_author_url: string option;
    re_provider_name: string option;
    re_provider_url: string option;
    re_cache_age: int option;
    re_thumbnail_url: string option;
    re_thumbnail_width: int option;
    re_thumbnail_height: int option;
    re_description: string option;
}

(** Information pertaining to an oEmbed provider. [pr_schemes] is the set of
    URL schemes that the provider can handle (with '*' wildcards), and
    [pr_endpoint] is the URL to which oEmbed requests are to be sent. *)
type provider = {
    pr_schemes: string list;
    pr_endpoint: string;
}

(** The format in which to parse or deparse responses. *)
type format = FO_json | FO_xml

(** Returns true if any of the URL schemes (in oEmbed scheme format) in the
    given list match or false otherwise. *)
val schemes_match : string list -> string -> bool

(** Returns the provider for the given URL. Raises [No_provider] if none of the
    providers matched the URL. *)
val provider_for_url : ?providers:provider list -> string -> provider

(** [request_url url] returns the URL to which a GET request should be made to
    retrieve the oEmbed response. Raises [No_provider] if none of the providers
    match the URL. *)
val request_url : ?providers:provider list -> ?format:format -> ?max_width:int
    -> ?max_height:int -> string -> string

(** [parse_response resp] parses the oEmbed response [resp] and returns a
    [response] record. *)
val parse_response : ?format:format -> string -> response

(** Performs an oEmbed request (using [Http_client.Convenience.http_get]) to
    retrieve the embedded content for [url] and returns a [response] record. *)
val get : ?providers:provider list -> ?format:format -> ?max_width:int
    -> ?max_height:int -> string -> response

(** Returns the given oEmbed response as a JSON or XML string. *)
val deparse_response : ?format:format -> response -> string

