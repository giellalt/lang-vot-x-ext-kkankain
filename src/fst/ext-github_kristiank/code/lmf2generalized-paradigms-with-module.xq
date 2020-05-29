xquery version "3.0" encoding "UTF-8";
import module namespace pjson = "http://keeleleek.ee/pextract/pjson" at "./karp-json.xqm";
import module namespace lmf = "http://keeleleek.ee/lmf" at "./lmf.xqm";
import module namespace giellatekno = "http://giellatekno.uit.no" at "./giellatekno.xqm";


(:~
 : This script is a proof-of-concept of the paradigm generalization method introduced in:
 : "A Computational Model for the Linguistic Notion of Morphological Paradigm" (Silfverberg, Miikka, Ling Liu & Mans Hulden. 2018)
 : 
 : @author Kristian Kankainen
 : @date 2018
 : @version 1.0
 :)

(: Read in the LMF :)
(:let $lmf := pjson:karp-pjson2lmf("../data/karp-json/votiska.json",
                                 "../data/karp-json/votiskaparadigms.json")
:)
(:let $lmf := doc("../data/pextract/vot-commonNoun.lmf"):)
let $lmf := doc("../data/lmf.xml")

let $generalmorphologicalpatterns := $lmf//MorphologicalPattern ! lmf:get-general-morphological-pattern(.)
let $countbefore := count($generalmorphologicalpatterns)

let $classes := 
  for $generalpattern in $generalmorphologicalpatterns
    let $id := $generalpattern/feat[@att="id"]/@val/data()
    let $samegeneralpatterns :=
      for $anotherpattern in $generalmorphologicalpatterns
        let $id2 := $anotherpattern/feat[@att="id"]/@val/data()
        return
          if (
            not($generalpattern is $anotherpattern)
            and
            deep-equal($generalpattern/TransformSet, $anotherpattern/TransformSet)
          )
          then ($id2)
          else ()
    let $all-samegeneralpatterns-nicenames := 
          ($id, $samegeneralpatterns) ! (fn:substring-after(.,"as") => fn:lower-case()) => sort()
    return string-join(
      (
        string-join($all-samegeneralpatterns-nicenames[fn:position() < fn:last()], ", "),
        $all-samegeneralpatterns-nicenames[fn:last()]
      ), " and ")

let $distinct-classes := distinct-values($classes)

return string-join($distinct-classes, out:nl()||out:nl())