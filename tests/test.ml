
open CalendarLib

open QuickCheck
open QuickCheck_gen

open Bson

let ( |> ) x f = f x
let ( <| ) f x = f x
let ( & ) f x = f x
let pack1 g = promote (fun () -> g)
let pack lst = List.map pack1 lst
let unpack1 f = f ()
let unpack lst  = List.map unpack1 lst

(* deriving *)

let string_wrapper fn =
  map_gen fn arbitrary_string

let arbitrary_cstring =
  arbitrary_string
let arbitrary_double =
  map_gen (fun f -> Double f) arbitrary_float
let arbitrary_elstring =
  string_wrapper (fun s -> String s)
let arbitrary_objectid =
  map_gen (fun s -> ObjectId (to_objectid s)) (arbitrary_stringN 12)
let arbitrary_datetime =
  map_gen (fun f -> Datetime (Calendar.from_unixfloat f)) arbitrary_float
let arbitrary_boolean =
  map_gen (fun b -> Boolean b) arbitrary_bool
let arbitrary_regex =
  map_gen (fun p -> Regex p) & arbitrary_pair arbitrary_cstring arbitrary_cstring
let arbitrary_jscode =
  string_wrapper (fun s -> JSCode s)
let arbitrary_symbol =
  string_wrapper (fun s -> Symbol s)
let arbitrary_elint32 =
  map_gen (fun i -> Int32 i ) arbitrary_int32
let arbitrary_timestamp =
  map_gen (fun i -> Timestamp i) arbitrary_int64
let arbitrary_elint64 =
  map_gen (fun i -> Int64 i) arbitrary_int64

let arbitrary_bin_generic =
  string_wrapper (fun s -> Generic s)
let arbitrary_bin_function =
  string_wrapper (fun s -> Function s)
let arbitrary_bin_genericold =
  string_wrapper (fun s -> GenericOld s)
let arbitrary_bin_uuid =
  string_wrapper (fun s -> GenericOld s)
let arbitrary_bin_md5 =
  string_wrapper (fun s -> MD5 s)
let arbitrary_bin_userdefined =
  string_wrapper (fun s -> UserDefined s)

let arbitrary_binary =
  map_gen (fun bd -> BinaryData bd) & oneof [arbitrary_bin_generic;
                                             arbitrary_bin_function;
                                             arbitrary_bin_genericold;
                                             arbitrary_bin_uuid;
                                             arbitrary_bin_md5;
                                             arbitrary_bin_userdefined
                                            ]


let rec arbitrary_element () =
  oneof (List.append
           [promote arbitrary_eldocument;
            promote arbitrary_array;
            promote arbitrary_jscodewithscope
           ]
           (pack [arbitrary_double;
                  arbitrary_elstring;
                  arbitrary_binary;
                  arbitrary_objectid;
                  arbitrary_datetime;
                  ret_gen Null;
                  arbitrary_boolean;
                  arbitrary_regex;
                  arbitrary_jscode;
                  arbitrary_symbol;
                  arbitrary_elint32;
                  arbitrary_timestamp;
                  arbitrary_elint64;
                  ret_gen Minkey;
                  ret_gen Maxkey;
                 ]
           ))
and arbitrary_array () =
  map_gen (fun a -> Array (unpack a)) & arbitrary_list & arbitrary_element ()
and arbitrary_item () =
  arbitrary_pair (pack1 arbitrary_cstring) (arbitrary_element ())
and arbitrary_eldocument () =
  map_gen (fun d -> Document d) & arbitrary_document ()
and arbitrary_jscodewithscope () =
  map_gen (fun (s, d) -> JSCodeWithScope (s, d)) &
    arbitrary_pair arbitrary_string & arbitrary_document ()
and arbitrary_document () =
  (arbitrary_list & (arbitrary_item () >>= (fun (us, ue) ->
    pack1 & ret_gen (unpack1 us, unpack1 ue)))) >>= (fun lg ->
      ret_gen & unpack lg)

let show_cstring = show_string

let sw cons cont = Printf.sprintf "%s %s" cons cont

let rec show_element = function
  | Double d -> sw "Double" & show_float d
  | String s -> sw "String" & show_string s
  | Document d -> sw "Document" & show_document d
  | Array a -> sw "Array" & show_array a
  | BinaryData bd -> sw "BinaryData" & show_binary bd
  | ObjectId s -> sw "ObjectId" & show_string & from_objectid s
  | Datetime d -> sw "Datetime" & (Printer.Calendar.sprint "%c" d)
  | Null -> "Null"
  | Boolean b -> sw "Boolean" & show_bool b
  | Regex p -> sw "Regex" & show_pair show_cstring show_cstring p
  | JSCode s -> sw "JSCode" & show_string s
  | Symbol s -> sw "Symbol" & show_string s
  | JSCodeWithScope p -> sw "JSCodeWithScope" & show_jscodewithscope p
  | Int32 i -> sw "Int32" & show_int32 i
  | Timestamp i -> sw "Timestamp" & show_int64 i
  | Int64 i -> sw "Int64" & show_int64 i
  | Minkey -> "Minkey"
  | Maxkey -> "Maxkey"
and show_binary = function
  | Generic s -> sw "Generic" & show_string s
  | Function s -> sw "Function" & show_string s
  | GenericOld s -> sw "GenericOld" & show_string s
  | UUID s -> sw "UUID" & show_string s
  | MD5 s -> sw "MD5" & show_string s
  | UserDefined s -> sw "UserDefined" & show_string s
and show_jscodewithscope p = show_pair show_string show_document p
and show_item p = show_pair show_cstring show_element p
and show_array l = show_list show_element l
and show_document l = show_list show_item l

let testable_doc_to_bool =
  testable_fun (arbitrary_document ()) show_document testable_bool

let cld = quickCheck testable_doc_to_bool

let prop_parseunparse doc =
  try
    decode (encode doc) = doc
  with
    |MalformedBSON s ->
      let () = print_endline s in
      false
    | Stream.Failure ->
      let () = Printf.printf "Stream.Failure\n" in
      false
    | Stream.Error s ->
      let () = Printf.printf "Stream.Error %s\n" s in
      false

let testable_objectid_to_bool =
  testable_fun arbitrary_objectid show_element testable_bool

let prop_objectid = function
  | ObjectId s -> String.length (from_objectid s) = 12
  | Double _ | String _ | Document _ | Array _ | BinaryData _
  | Datetime _ | Null | Boolean _ | Regex _ | JSCode _
  | Symbol _ | JSCodeWithScope _ | Int32 _ | Timestamp _
  | Int64 _  | Minkey | Maxkey -> true

let clo = quickCheck testable_objectid_to_bool

let main () =
  clo prop_objectid;
  cld prop_parseunparse

let () =
  main ()
