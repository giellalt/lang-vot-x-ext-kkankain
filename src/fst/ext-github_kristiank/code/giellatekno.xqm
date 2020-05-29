xquery version "3.0" encoding "UTF-8";
module namespace giellatekno = "http://giellatekno.uit.no";
import module namespace functx = 'http://www.functx.com';


(:~
 : Module for working with conversion to Giellatekno infrastructure 
 : from the Lexical Markup Framework.
 :
 : @author Kristian Kankainen
 : @copyright MTÜ Keeleleek, 2019
 : @date 2019
 : @version 1.0
 : @see https://github.com/kristiank/MA-thesis
 :)




(:~ Abstract function for creating a conversion table, if a term is not found,
 : it is returned as is.
 : @since 1.0
 : @param $term as xs:string
 : @return Giellatekno specific term as xs:string
 :)
declare variable $giellatekno:mkTranslator := 
function($translations as map(xs:string, xs:string)) {
  function($search-term) {
    ($translations?($search-term), $search-term)[1]
  }
};

(:~ Conversion table for parts of speech as used in Giellatekno's YAML tests
 : if a term is not found, it is returned as is.
 : @since 1.0
 : @param $term as xs:string
 : @return Giellatekno specific term as xs:string
 :)
declare variable $giellatekno:get-tests-pos := 
  $giellatekno:mkTranslator(
    map{
      "nn": "Noun",
      "commonNoun": "Noun"
    }
  );
  
(:~ Conversion table for parts of speech as used in Giellatekno's FSTs
 : if a term is not found, it is returned as is.
 : @since 1.0
 : @param $term as xs:string
 : @return Giellatekno specific term as xs:string
 :)
declare variable $giellatekno:get-fst-pos := 
  $giellatekno:mkTranslator(
    map{
      "nn": "N",
      "commonNoun": "N"
    }
  );


(:~ Conversion table for different terms (mainly grammatical numbers and cases)
 : if a term is not found, it is returned as is.
 : @since 1.0
 : @param $term as xs:string
 : @return Giellatekno specific term as xs:string
 :)
declare variable $giellatekno:get-giella-term :=
  $giellatekno:mkTranslator(map{
    "singular":    "Sg",
    "plural":      "Pl",
    "nominative":  "Nom",
    "genitive":    "Gen",
    "partitive":   "Par",
    "illative":    "Ill",
    "inessive":    "Ine",
    "elative":     "Ela",
    "adessive":    "Ade",
    "ablative":    "Abl",
    "allative":    "All",
    "translative": "Tra",
    "terminative": "Ter",
    "comitative":  "Com"
});




(:~ Converts a utf8 string into ascii representation suitable for Giellatekno filenames
 : @since 1.0
 : @param $name as xs:string
 : @return the name in ascii as xs:string
 :)
declare variable $giellatekno:get-file-name := 
  function ($name as xs:string) {
  $name => translate("ü", "ue")
        => translate("ö", "oe")
        => translate("ä", "ae")
        => translate("õ", "w")
};




(:~ Returns the lexc lexicon name for a paradigm
 : @since 1.0
 : @param $paradigm as element(MorphologicalPattern)
 : @return the lexicon name as xs:string
 :)
declare function giellatekno:paradigm-to-lexc-name(
  $paradigm as element(MorphologicalPattern)
) as xs:string {
  let $paradigm-id  := $paradigm/feat[@att="id"]/@val/data()
                       => substring-after("as")
                       => lower-case()
  let $paradigm-pos := $paradigm/feat[@att="partOfSpeech"]/@val/data()
                       => $giellatekno:get-fst-pos()
  return $paradigm-pos || "_" || $paradigm-id
};




(:~ Returns the lexc and fst tag name for a paradigm
 : @since 1.0
 : @param $paradigm as element(MorphologicalPattern)
 : @return the paradigm tag as xs:string
 :)
declare function giellatekno:paradigm-to-lexc-tag(
  $paradigm as element(MorphologicalPattern)
) as xs:string {
  let $paradigm-id  := $paradigm/feat[@att="id"]/@val/data()
                       => substring-after("as")
                       => lower-case()
  let $paradigm-pos := $paradigm/feat[@att="partOfSpeech"]/@val/data()
                       => $giellatekno:get-fst-pos()
  return "+Paradigm/" || $paradigm-id || "_" || $paradigm-pos
};




(:~ Makes a TransformSet "regular", i.e shape of 'Const Var (Const Var)* Const' 
 : by inserting Processes with empty constants.
 : @since 1.0
 : @param $transformset as element(TransformSet)
 : @return regular transformset as element(TransformSet)
 :)
declare function giellatekno:regularize-transformset(
  $transformset as element(TransformSet)
) as element(TransformSet)
{
  $transformset 
  => giellatekno:regularize-transformset-circumpend() 
  => giellatekno:regularize-transformset-interpend()
};


(:~ Helper function for giellatekno:regularize-transformset
 : i.e inserts Processes with empty constants between two Processes with variable.
 : @since 1.0
 : @param $transformset as element(TransformSet)
 : @return regular transformset as element(TransformSet)
 :)
declare function giellatekno:regularize-transformset-interpend(
  $transformset as element(TransformSet)
) as element(TransformSet) 
{
  let $process-list := $transformset/Process
  let $interpended :=
  for $i in (2 to count($process-list))
    let $previous := $process-list[$i - 1]/feat[@att="processType"]/@val/data()
    let $current  := $process-list[$i]/feat[@att="processType"]/@val/data()
    return
    if  ($current = "pextractAddVariable" and $previous = "pextractAddVariable")
    then(giellatekno:process-with-empty-constant(), $process-list[$i])
    else($process-list[$i])
  return
    <TransformSet>
    {
      $transformset/GrammaticalFeatures,
      $process-list[1], $interpended
    }
    </TransformSet>
    
};



(:~ Helper function for giellatekno:regularize-transformset
 : i.e inserts Processes with empty constants between two Processes with variable.
 : @since 1.0
 : @param $transformset as element(TransformSet)
 : @return circumpended transformset as element(TransformSet)
 :)
declare function giellatekno:regularize-transformset-circumpend(
  $transformset as element(TransformSet)
) as element(TransformSet) 
{
  let $processes := (
  if($transformset/Process[1]/feat[@att="processType"]/@val/data() != "pextractAddConstant")
          then(giellatekno:process-with-empty-constant())
          else(),
  $transformset/Process,
  if($transformset/Process[last()]/feat[@att="processType"]/@val/data() != "pextractAddConstant")
          then(giellatekno:process-with-empty-constant())
          else()
  )
  return
    <TransformSet>
    {
      $transformset/GrammaticalFeatures,
      $processes
    }
    </TransformSet>
};

(:~ Helper function for giellatekno:regularize-transformset
 : i.e creates a Process with an empty constant
 : @since 1.0
 : @return Process with empty constant
 :)
declare function giellatekno:process-with-empty-constant(
) as element(Process)
{
  <Process>
    <feat att="operator" val="addAfter"/>
    <feat att="processType" val="pextractAddConstant"/>
    <feat att="stringValue" val=""/>
  </Process>
};