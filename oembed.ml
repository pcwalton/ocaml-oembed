(*
 * ocaml-oembed/oembed.ml
 *
 * Copyright (c) 2010 Patrick Walton <pcwalton@mimiga.net>
 *)

module EH = ExtHashtbl.Hashtbl
module H = Hashtbl
module Op = Option

exception Malformed
exception No_provider

type url = string
type html = string

type dimensions = {
    di_width: int;
    di_height: int;
}

type resource_type =
| RT_photo of url * dimensions
| RT_video of html * dimensions
| RT_rich of html * dimensions
| RT_link

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
    re_description: string;
}

type provider = {
    pr_schemes: string list;
    pr_endpoint: string;
}

type format = FO_json | FO_xml

let backslash_star = lazy(Str.regexp_string "\\*")

let embedly = [
    { pr_schemes = [ "*" ]; pr_endpoint = "http://api.embed.ly/v1/api/oembed" }
]

let json_to_kvps json =
    try
        let json = Json_type.Browse.objekt (Json_io.json_of_string json) in
        let json = Json_type.Browse.make_table json in
        EH.map begin function
            | Json_type.String s -> s
            | Json_type.Int n -> string_of_int n
            | _ -> raise Malformed
        end json
    with Json_type.Json_error _ -> raise Malformed

let xml_to_kvps xml =
    let xml = Xml.parse_string xml in
    let kvps =
        try
            Xml.map begin fun child ->
                (Xml.tag child, Xml.pcdata (List.hd (Xml.children child)))
            end xml
        with Xml.Not_element _ | Xml.Not_pcdata _ -> raise Malformed in
    EH.of_enum (ExtList.List.enum kvps)

let kvps_to_json kvps =
    let kvps = List.map begin function
        | (key, `String str) -> (key, Json_type.Build.string str)
        | (key, `Int n) -> (key, Json_type.Build.int n)
    end kvps in
    Json_io.string_of_json (Json_type.Build.objekt kvps)

let kvps_to_xml kvps =
    let tags =
        List.map begin function
        | (key, `String str) -> Xml.Element(key, [], [ Xml.PCData str ])
        | (key, `Int n) ->
            Xml.Element(key, [], [ Xml.PCData(string_of_int n) ])
    end kvps in
    Xml.to_string(Xml.Element("oembed", [], tags))

let provider_for_url ?providers:(providers=embedly) url =
    try
        List.find begin fun provider ->
            List.exists begin fun scheme ->
                let re = Str.global_replace (Lazy.force backslash_star) ".*"
                    (Str.quote scheme) in
                Str.string_match (Str.regexp re) url 0
            end provider.pr_schemes
        end providers
    with Not_found -> raise No_provider

let request_url ?providers:(providers=embedly) ?format:(format=FO_json)
        ?max_width:max_width ?max_height:max_height url =
    let provider = provider_for_url ~providers:providers url in

    let params = DynArray.create() in
    DynArray.add params ("url", url);
    begin
        match format with
        | FO_json -> DynArray.add params ("format", "json")
        | FO_xml -> DynArray.add params ("format", "xml")
    end;
    Op.may (fun n -> DynArray.add params ("maxwidth", (string_of_int n)))
        max_width;
    Op.may (fun n -> DynArray.add params ("maxheight", (string_of_int n)))
        max_height;
    let query_string = Netencoding.Url.mk_url_encoded_parameters
        (DynArray.to_list params) in

    provider.pr_endpoint ^ "?" ^ query_string

let parse_response ?format:(format=FO_json) resp =
    let kvps =
        match format with
        | FO_json -> json_to_kvps resp
        | FO_xml -> xml_to_kvps resp in
    
    try
        let get_dimensions() =
            {
                di_width = int_of_string (H.find kvps "width");
                di_height = int_of_string (H.find kvps "height")
            }
        in
        let resource_type =
            match Hashtbl.find kvps "type" with
            | "photo" -> RT_photo(H.find kvps "url", get_dimensions())
            | "video" -> RT_video(H.find kvps "html", get_dimensions())
            | "link" -> RT_link
            | "rich" -> RT_rich(H.find kvps "html", get_dimensions())
            | _ -> raise Malformed
        in
        {
            re_type = resource_type;
            re_title = EH.find_option kvps "title";
            re_author_name = EH.find_option kvps "author_name";
            re_author_url = EH.find_option kvps "author_url";
            re_provider_name = EH.find_option kvps "provider_hame";
            re_provider_url = EH.find_option kvps "provider_url";
            re_cache_age =
                Op.map int_of_string (EH.find_option kvps "cache_age");
            re_thumbnail_url = EH.find_option kvps "thumbnail_url";
            re_thumbnail_width =
                Op.map int_of_string (EH.find_option kvps "thumbnail_width");
            re_thumbnail_height =
                Op.map int_of_string (EH.find_option kvps "thumbnail_height");
            re_description = H.find kvps "description"
        }
    with Not_found -> raise Malformed

let get ?providers:(providers=embedly) ?format:(format=FO_json)
        ?max_width:max_width ?max_height:max_height url =
    let req_url = request_url ~providers:providers ~format:format
        ?max_width:max_width ?max_height:max_height url in
    let body = Http_client.Convenience.http_get req_url in
    parse_response ~format:format body

let deparse_response ?format:(format=FO_json) response =
    let result = DynArray.create() in
    let add_dimensions dimensions =
        DynArray.add result ("width", `Int dimensions.di_width);
        DynArray.add result ("height", `Int dimensions.di_height)
    in
    let ty =
        match response.re_type with
        | RT_photo(url, dims) ->
            add_dimensions dims;
            DynArray.add result ("url", `String url);
            "photo"
        | RT_video(html, dims) ->
            add_dimensions dims;
            DynArray.add result ("html", `String html);
            "video"
        | RT_rich(html, dims) ->
            add_dimensions dims;
            DynArray.add result ("html", `String html);
            "rich"
        | RT_link -> "link" in
    DynArray.add result ("type", `String ty);
   
    let add_string name =
        Op.may (fun s -> DynArray.add result (name, `String s))
    in
    let add_int name = Op.may (fun n -> DynArray.add result (name, `Int n)) in

    add_string "title" response.re_title;
    add_string "author_name" response.re_author_name;
    add_string "author_url" response.re_author_url;
    add_string "provider_name" response.re_provider_name;
    add_string "provider_url" response.re_provider_url;
    add_int "cache_age" response.re_cache_age;
    add_string "thumbnail_url" response.re_thumbnail_url;
    add_int "thumbnail_width" response.re_thumbnail_width;
    add_int "thumbnail_height" response.re_thumbnail_height;
    DynArray.add result ("description", `String response.re_description);

    match format with
    | FO_json -> kvps_to_json (DynArray.to_list result)
    | FO_xml -> kvps_to_xml (DynArray.to_list result)

