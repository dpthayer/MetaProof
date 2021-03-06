(*  Title:      Pure/ProofGeneral/pgip_input.ML
    Author:     David Aspinall

PGIP abstraction: input commands.
*)

signature PGIPINPUT =
sig
    (* These are the PGIP commands to which we respond. *) 
    datatype pgipinput = 
    (* protocol/prover config *)
      Askpgip        of { }
    | Askpgml        of { } 
    | Askconfig      of { }
    | Askprefs       of { }
    | Setpref        of { name:string, prefcategory:string option, value:string }
    | Getpref        of { name:string, prefcategory:string option }
    (* prover control *)
    | Proverinit     of { }
    | Proverexit     of { }
    | Setproverflag  of { flagname:string, value: bool }
    (* improper proof commands: control proof state *)
    | Dostep         of { text: string }
    | Undostep       of { times: int }
    | Redostep       of { }
    | Abortgoal      of { }
    | Forget         of { thyname: string option, name: string option, 
                          objtype: PgipTypes.objtype option }
    | Restoregoal    of { thmname : string }
    (* context inspection commands *)
    | Askids         of { url: PgipTypes.pgipurl option,
                          thyname: PgipTypes.objname option,
                          objtype: PgipTypes.objtype option }
    | Askrefs        of { url: PgipTypes.pgipurl option,
                          thyname: PgipTypes.objname option,
                          objtype: PgipTypes.objtype option,
                          name: PgipTypes.objname option }
    | Showid         of { thyname: PgipTypes.objname option, 
                          objtype: PgipTypes.objtype, 
                          name: PgipTypes.objname }
    | Askguise       of { }
    | Parsescript    of { text: string, location: PgipTypes.location,
                          systemdata: string option } 
    | Showproofstate of { }
    | Showctxt       of { }
    | Searchtheorems of { arg: string }
    | Setlinewidth   of { width: int }
    | Viewdoc        of { arg: string }
    (* improper theory-level commands *)
    | Doitem         of { text: string }
    | Undoitem       of { }
    | Redoitem       of { }
    | Aborttheory    of { }
    | Retracttheory  of { thyname: string }
    | Loadfile       of { url: PgipTypes.pgipurl }
    | Openfile       of { url: PgipTypes.pgipurl }
    | Closefile      of { }
    | Abortfile      of { }
    | Retractfile    of { url: PgipTypes.pgipurl }
    | Changecwd      of { url: PgipTypes.pgipurl }
    | Systemcmd      of { arg: string }
    (* unofficial escape command for debugging *)
    | Quitpgip       of { }

    val input: Markup.T * XML.tree list -> pgipinput option  (* raises PGIP *)
end

structure PgipInput : PGIPINPUT = 
struct

open PgipTypes

(*** PGIP input ***)

datatype pgipinput = 
         (* protocol/prover config *)
         Askpgip        of { }
       | Askpgml        of { } 
       | Askconfig      of { }
       | Askprefs       of { }
       | Setpref        of { name:string, prefcategory:string option, value:string }
       | Getpref        of { name:string, prefcategory:string option }
       (* prover control *)
       | Proverinit     of { }
       | Proverexit     of { }
       | Setproverflag  of { flagname:string, value: bool }
       (* improper proof commands: control proof state *)
       | Dostep         of { text: string }
       | Undostep       of { times: int }
       | Redostep       of { }
       | Abortgoal      of { }
       | Forget         of { thyname: string option, name: string option, 
                             objtype: PgipTypes.objtype option }
       | Restoregoal    of { thmname : string }
       (* context inspection commands *)
       | Askids         of { url: PgipTypes.pgipurl option,
                             thyname: PgipTypes.objname option,
                             objtype: PgipTypes.objtype option }
       | Askrefs        of { url: PgipTypes.pgipurl option,
                             thyname: PgipTypes.objname option,
                             objtype: PgipTypes.objtype option,
                             name: PgipTypes.objname option }
       | Showid         of { thyname: PgipTypes.objname option, 
                             objtype: PgipTypes.objtype, 
                             name: PgipTypes.objname }
       | Askguise       of { }
       | Parsescript    of { text: string, location: location,
                             systemdata: string option } 
       | Showproofstate of { }
       | Showctxt       of { }
       | Searchtheorems of { arg: string }
       | Setlinewidth   of { width: int }
       | Viewdoc        of { arg: string }
       (* improper theory-level commands *)
       | Doitem         of { text: string }
       | Undoitem       of { }
       | Redoitem       of { }
       | Aborttheory    of { }
       | Retracttheory  of { thyname: string }
       | Loadfile       of { url: pgipurl }
       | Openfile       of { url: pgipurl }
       | Closefile      of { }
       | Abortfile      of { }
       | Retractfile    of { url: pgipurl }
       | Changecwd      of { url: pgipurl }
       | Systemcmd      of { arg: string }
       (* unofficial escape command for debugging *)
       | Quitpgip       of { }

(* Extracting content from input XML elements to make a PGIPinput *)
local

    val thyname_attro = get_attr_opt "thyname"
    val thyname_attr = get_attr "thyname"
    val name_attr = get_attr "name"
    val name_attro = get_attr_opt "name"
    val thmname_attr = get_attr "thmname"
    val flagname_attr = get_attr "flagname"
    val value_attr = get_attr "value"

    fun objtype_attro attrs = if has_attr "objtype" attrs then
                                  SOME (objtype_of_attrs attrs)
                              else NONE

    fun pgipurl_attro attrs = if has_attr "url" attrs then
                                  SOME (pgipurl_of_attrs attrs)
                              else NONE

    val times_attr = read_pgipnat o (get_attr_dflt "times" "1")
    val prefcat_attr = get_attr_opt "prefcategory"

    fun xmltext (XML.Text text :: ts) = text ^ xmltext ts
      | xmltext [] = ""
      | xmltext _ = raise PGIP "Expected text (PCDATA/CDATA)"

    exception Unknown
    exception NoAction
in

(* Return a valid PGIP input command.
   Raise PGIP exception for invalid data.
   Return NONE for unknown/unhandled commands. 
*)
fun input ((elem, attrs), data) =
SOME 
 (case elem of 
     "askpgip"        => Askpgip { }
   | "askpgml"        => Askpgml { }
   | "askconfig"      => Askconfig { }
   (* proverconfig *)
   | "askprefs"       => Askprefs { }
   | "getpref"        => Getpref { name = name_attr attrs, 
                                   prefcategory = prefcat_attr attrs }
   | "setpref"        => Setpref { name = name_attr attrs, 
                                   prefcategory = prefcat_attr attrs,
                                   value = xmltext data }
   (* provercontrol *)
   | "proverinit"     => Proverinit { }
   | "proverexit"     => Proverexit { }
   | "setproverflag"  => Setproverflag { flagname = flagname_attr attrs,
                                         value = read_pgipbool (value_attr attrs) }
   (* improperproofcmd: improper commands not in script *)
   | "dostep"         => Dostep    { text = xmltext data }
   | "undostep"       => Undostep  { times = times_attr attrs }
   | "redostep"       => Redostep  { } 
   | "abortgoal"      => Abortgoal { }
   | "forget"         => Forget { thyname = thyname_attro attrs, 
                                  name = name_attro attrs,
                                  objtype = objtype_attro attrs }
   | "restoregoal"    => Restoregoal { thmname = thmname_attr attrs}
   (* proofctxt: improper commands *)
   | "askids"         => Askids { url = pgipurl_attro attrs,
                                  thyname = thyname_attro attrs, 
                                  objtype = objtype_attro attrs }
   | "askrefs"        => Askrefs { url = pgipurl_attro attrs,
                                   thyname = thyname_attro attrs, 
                                   objtype = objtype_attro attrs,
                                   name = name_attro attrs }
   | "showid"         => Showid { thyname = thyname_attro attrs,
                                  objtype = objtype_of_attrs attrs,
                                  name = name_attr attrs }
   | "askguise"       => Askguise { }
   | "parsescript"    => Parsescript { text = (xmltext data),
                                       systemdata = get_attr_opt "systemdata" attrs,
                                       location = location_of_attrs attrs }
   | "showproofstate" => Showproofstate { }
   | "showctxt"       => Showctxt { }
   | "searchtheorems" => Searchtheorems { arg = xmltext data }
   | "setlinewidth"   => Setlinewidth   { width = read_pgipnat (xmltext data) }
   | "viewdoc"        => Viewdoc { arg = xmltext data }
   (* improperfilecmd: theory-level commands not in script *)
   | "doitem"         => Doitem  { text = xmltext data }
   | "undoitem"       => Undoitem { }
   | "redoitem"       => Redoitem { }
   | "aborttheory"    => Aborttheory { }
   | "retracttheory"  => Retracttheory { thyname = thyname_attr attrs }
   | "loadfile"       => Loadfile { url = pgipurl_of_attrs attrs }
   | "openfile"       => Openfile { url = pgipurl_of_attrs attrs }
   | "closefile"      => Closefile { }
   | "abortfile"      => Abortfile { }
   | "retractfile"    => Retractfile { url = pgipurl_of_attrs attrs }
   | "changecwd"      => Changecwd { url = pgipurl_of_attrs attrs }
   | "systemcmd"      => Systemcmd { arg = xmltext data }
   (* unofficial command for debugging *)
   | "quitpgip" => Quitpgip { }

   (* We allow sending proper document markup too; we map it back to dostep   *)
   (* and strip out metainfo elements. Markup correctness isn't checked: this *)
   (* is a compatibility measure to make it easy for interfaces.              *)
   | x => if member (op =) PgipMarkup.doc_markup_elements x then
              if member (op =) PgipMarkup.doc_markup_elements_ignored x then
                  raise NoAction
              else 
                  Dostep { text = xmltext data } (* could separate out Doitem too *)
          else raise Unknown) 
    handle Unknown => NONE | NoAction => NONE
end

end
