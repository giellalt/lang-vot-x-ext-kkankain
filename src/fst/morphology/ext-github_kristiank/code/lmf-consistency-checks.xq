xquery version "3.0" encoding "UTF-8";
import module namespace pjson = "http://keeleleek.ee/pextract/pjson" at "./karp-json.xqm";
import module namespace lmf = "http://keeleleek.ee/lmf" at "./lmf.xqm";

(: Read in the LMF :)
let $lmf := doc("../data/lmf.xml")

return lmf:check-if-listed-patterns-exist($lmf)