xquery version "3.0" encoding "UTF-8";
import module namespace pjson = "http://keeleleek.ee/pextract/pjson" at "./karp-json.xqm";
import module namespace lmf = "http://keeleleek.ee/lmf" at "./lmf.xqm";
import module namespace giellatekno = "http://giellatekno.uit.no" at "./giellatekno.xqm";


(:~
 : This script converts the LMF lexical resource into lexc stems representation
 : used in the Giellatekno infrastructure.
 :
 : The lexc files are saved separately for each part of speech in the folder:
 :   morphology/stems/PoS.lexc
 : 
 : @author Kristian Kankainen
 : @version 1.0
 :)


(: Read in the LMF :)
let $lmf := doc("../data/lmf.xml")


let $latex-tables :=
for $paradigm in $lmf//MorphologicalPattern
  let $paradigm-id := $paradigm/feat[@att="id"]/@val/data()
  let $lexical-entries := $lmf//LexicalEntry[@morphologicalPatterns = $paradigm-id]
                              /Lemma/feat[@att="writtenForm"]/@val/data()
  order by count($lexical-entries) descending
  let $table-start := ("\begin{table}",
                       "\centering", 
                       "\begin{tabular}[H]{l l l}",
                       "ühisosajada &amp; muutvormimall &amp; tunnused \\",
                       "\hline"
                      )
  let $table-content := 
    for $transformset in $paradigm/TransformSet
      let $gramfeats := string-join((
        "\textsc{",
        $transformset/GrammaticalFeatures/feat/@val/data() ! $giellatekno:get-giella-term(.) ! lower-case(.),
        "} \\"), " "
      )
      let $pattern :=
        for $process in $transformset/Process
          return switch ($process/feat[@att="processType"]/@val/data())
            case "pextractAddVariable" return
              "$x_" || $process/feat[@att="variableNum"]/@val/data() || "$"
            default return
              $process/feat[@att="stringValue"]/@val/data()
       let $model-word :=
         for $process in $transformset/Process
          return switch ($process/feat[@att="processType"]/@val/data())
            case "pextractAddVariable" return
              "\underline{" || 
              lmf:get-attested-var-values($paradigm)[1]
                /feat[@att = $process/feat[@att="variableNum"]/@val/data()]
                /@val/data() || "}"
            default return
              $process/feat[@att="stringValue"]/@val/data()
       return concat(string-join($model-word, " "), " &amp; ", string-join($pattern, " + "), " &amp; ", $gramfeats)
  let $table-end := (
    "\end{tabular}",
    "\caption{Tüüpsõna \textit{" || $paradigm/feat[@att="id"]/@val/data() => substring-after("as") => lower-case() || "} ekstraheeritud muutvormimall (hõlmab lekseeme: \vadja{"|| string-join($lexical-entries, ", ") ||"}).}",
    (: "\label{}" :)
    "\end{table}",
    "\clearpage",
    ""
  )
  let $latex-table := string-join((
    $table-start, $table-content, $table-end
  ), out:nl())
  return "\paragraph{" || $lexical-entries[1] || "}" || out:nl() || out:nl() || $latex-table


let $latex-document := string-join((
  "\documentclass[12pt,a4paper]{article}

\usepackage[top=4cm, bottom=3cm, left=4cm, right=2.5cm]{geometry}

% polyglossia
\usepackage{polyglossia}
\usepackage{fontspec}
\usepackage{xunicode}
\usepackage{xltxtra}
\usepackage{url}
\usepackage{expex}

% Use a Free/Libre font with Finnish–Hungarian-Cyrillic-UPA coverage
\setmainfont[Mapping=tex-text]{Linux Libertine O}
% set languages to use
\setmainlanguage{estonian}
\setotherlanguages{english}

\newcommand{\vadja}[1]{\textit{#1}}
\newcommand{\msd}[1]{\textsc{#1}}

\begin{document}
",
$latex-tables,
"\end{document}"
), out:nl())



return file:write-text(
    (:"/home/kristian/Projektid/MA-thesis/thesis/paradigm-tables.tex",:)
    "/home/kristian/Projektid/MA-thesis/thesis/appendix-morphological-patterns.tex",
    string-join($latex-document, out:nl())
  )