xquery version "3.0" encoding "UTF-8";
import module namespace pjson = "http://keeleleek.ee/pextract/pjson" at "./karp-json.xqm";

(:~
 : This script converts Karp's json data into a holistic LexicalResource
 : represented as a Lexical Markup Framework XML and writes it into a file.
 :
 : @author Kristian Kankainen
 : @version 1.0
 :)

let $lexicon-json   := "../data/karp-json/votiska.json"
let $paradigms-json := "../data/karp-json/votiskaparadigms.json"

let $out-folder := "/home/kristian/Projektid/MA-thesis/data/"
let $file-name := "lmf.xml"
let $file-path := concat($out-folder, $file-name)

let $lmf := pjson:karp-pjson2lmf($lexicon-json, $paradigms-json)

return file:write(
           $file-path,
           $lmf
         )