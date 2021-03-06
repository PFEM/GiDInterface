##################################################################################
#   This file is common for all Kratos Applications.
#   Do not change anything here unless it's strictly necessary.
##################################################################################

namespace eval spdAux {
    # Namespace variables declaration
    
    variable uniqueNames
    variable initwind
    
    variable currentexternalfile
    variable refreshTreeTurn
    
    variable TreeVisibility
    
    variable ProjectIsNew
    variable GroupsEdited
}

proc spdAux::Init { } {
    # Namespace variables inicialization
    variable uniqueNames
    variable initwind
    variable currentexternalfile
    variable refreshTreeTurn
    variable TreeVisibility
    variable ProjectIsNew
    variable GroupsEdited

    set uniqueNames ""
    dict set uniqueNames "dummy" 0
    set initwind ""
    set  currentexternalfile ""
    set refreshTreeTurn 0
    set TreeVisibility 0
    set ProjectIsNew 0
    set GroupsEdited [dict create]

}

proc spdAux::RequestRefresh {} {
    variable refreshTreeTurn
    set refreshTreeTurn 1
}

proc spdAux::TryRefreshTree { } {
    variable refreshTreeTurn
    #W "HI"
    update
    update idletasks
    if {$refreshTreeTurn} {
        #W "there"
        catch {
            set foc [focus]
            set ::spdAux::refreshTreeTurn 0
            gid_groups_conds::actualize_conditions_window
            gid_groups_conds::actualize_conditions_window
            focus -force $foc
        }
        set ::spdAux::refreshTreeTurn 0
    }
    after 750 {spdAux::TryRefreshTree}
}

proc spdAux::OpenTree { } {
    variable TreeVisibility
    if {$TreeVisibility} {
        if {[gid_groups_conds::open_conditions window_type] ne "menu"} {
            gid_groups_conds::open_conditions menu
        }
    }
}

proc spdAux::EndRefreshTree { } {
    variable refreshTreeTurn
    set refreshTreeTurn 0
    after cancel {spdAux::TryRefreshTree}
}

# Includes
proc spdAux::processIncludes { } {
    customlib::UpdateDocument
    set root [customlib::GetBaseRoot]
    spdAux::processAppIncludes $root
    spdAux::processDynamicNodes $root
}

proc spdAux::processDynamicNodes { root } {
    foreach elem [$root getElementsByTagName "dynamicnode"] {
        set func [$elem getAttribute command]
        set ar [$elem getAttribute args]
        ${func} $elem $ar
    }
}

proc spdAux::processAppIncludes { root } {
    foreach elem [$root getElementsByTagName "appLink"] {
        set active [$elem getAttribute "active"]
        set appid [$elem getAttribute "appid"]
        set pn [$elem getAttribute "pn"]
        set prefix [$elem getAttribute "prefix"]
        set public 0
        if {[$elem hasAttribute "public"]} {set public [$elem getAttribute "public"]}
        set app [apps::NewApp $appid $pn $prefix]
        $app setPublic $public
        if {$active} {
            set dir $::Kratos::kratos_private(Path)
            set f [file join $dir apps $appid xml Main.spd]
            set processedAppnode [customlib::ProcessIncludesRecurse $f $dir]
            $root insertBefore $processedAppnode $elem
            $elem delete
        }
    }
}

proc spdAux::reactiveApp { } {
    #W "Reactive"
    variable initwind
    destroy $initwind
    
    set root [customlib::GetBaseRoot]
    set ::Model::SpatialDimension [[$root selectNodes "value\[@n='nDim'\]"] getAttribute v ]
    set appname [[$root selectNodes "hiddenfield\[@n='activeapp'\]"] @v ]

    apps::setActiveApp $appname
}

proc spdAux::deactiveApp { appid } {
    
    set root [customlib::GetBaseRoot]
    [$root selectNodes "hiddenfield\[@n='activeapp'\]"] setAttribute v ""
    foreach elem [$root getElementsByTagName "appLink"] {
        if {$appid eq [$elem getAttribute "appid"] && [$elem getAttribute "active"] eq "1"} {
            $elem setAttribute "active" 0
            break
        } 
    }
}
proc spdAux::activeApp { appid } {
    #W "Active $appid"
    variable initwind
    catch {
        set root [customlib::GetBaseRoot]
        [$root selectNodes "hiddenfield\[@n='activeapp'\]"] setAttribute v $appid
        foreach elem [$root getElementsByTagName "appLink"] {
            if {$appid eq [$elem getAttribute "appid"] && [$elem getAttribute "active"] eq "0"} {
                $elem setAttribute "active" 1
            } else {
                $elem setAttribute "active" 0
            }
        }
    }
    if {$::Kratos::must_quit} {return ""}
    set nd [$root selectNodes "value\[@n='nDim'\]"]
    if {[$nd getAttribute v] ne "wait"} {
        if {[$nd getAttribute v] ne "undefined"} {
            set ::Model::SpatialDimension [$nd getAttribute v]
            spdAux::SwitchDimAndCreateWindow $::Model::SpatialDimension
            spdAux::TryRefreshTree
        } {
            ::spdAux::CreateDimensionWindow
        }
    }
}

proc spdAux::CreateWindow {} {
    variable initwind
    
    set root [customlib::GetBaseRoot]
    
    set activeapp [ [$root selectNodes "hiddenfield\[@n='activeapp'\]"] getAttribute v]
    
    if {[winfo exist $initwind]} {destroy $initwind}
        
    if { $activeapp ne "" } {
        apps::setActiveApp $activeapp
        return ""
    }
    
    set w .gid.win_example
    toplevel $w
    wm withdraw $w
    
    
    set x [expr [winfo rootx .gid]+[winfo width .gid]/2-[winfo width $w]/2]
    set y [expr [winfo rooty .gid]+[winfo height .gid]/2-[winfo height $w]/2]
    
    wm geom $w +$x+$y
    wm transient $w .gid    
    
    InitWindow $w [_ "Kratos Multiphysics"] Kratos "" "" 1
    set initwind $w
    ttk::frame $w.top
    ttk::label $w.top.title_text -text [_ " Application market"]
    ttk::frame $w.information  -relief ridge 
    
    set appsid [::apps::getAllApplicationsID]
    set appspn [::apps::getAllApplicationsName]
    
    set col 0
    set row 0
    foreach appname $appspn appid $appsid {
        if {[apps::isPublic $appid]} {
            set img [::apps::getImgFrom $appid]
            ttk::button $w.information.img$appid -image $img -command [list apps::setActiveApp $appid]
            ttk::label $w.information.text$appid -text $appname
            
            grid $w.information.img$appid -column $col -row $row
            grid $w.information.text$appid -column $col -row [expr $row +1]
            
            incr col
            if {$col >= 5} {set col 0; incr row; incr row}
        }
    }

    # More button
    if {$::Kratos::kratos_private(DevMode) eq "dev"} {
        set more_path [file nativename [file join $::Kratos::kratos_private(Path) images "more.png"] ]
        set img [gid_themes::GetImageModule $more_path]
        ttk::button $w.information.img_more -image $img -command [list VisitWeb "https://github.com/KratosMultiphysics/GiDInterface"]
        ttk::label $w.information.text_more -text "More..."
        
        grid $w.information.img_more -column $col -row $row
        grid $w.information.text_more -column $col -row [expr $row +1]
    }

    grid $w.top
    grid $w.top.title_text
    
    grid $w.information
}

proc spdAux::CreateDimensionWindow { } {
    #package require anigif 1.3
    variable initwind
    
    set root [customlib::GetBaseRoot]
    
    set nd [ [$root selectNodes "value\[@n='nDim'\]"] getAttribute v]
    if { $nd ne "undefined" } {
        spdAux::SwitchDimAndCreateWindow $nd
        spdAux::RequestRefresh
    } {
        if {[llength $::Model::ValidSpatialDimensions] == 1} {
            spdAux::SwitchDimAndCreateWindow [lindex $::Model::ValidSpatialDimensions 0]
            spdAux::RequestRefresh
            return ""
        }
        set dir $::Kratos::kratos_private(Path)
        
        set initwind .gid.win_example
        if { [ winfo exist $initwind]} {
            destroy $initwind
        }
        toplevel $initwind
        wm withdraw $initwind
        
        set w $initwind
        
        set x [expr [winfo rootx .gid]+[winfo width .gid]/2-[winfo width $w]/2]
        set y [expr [winfo rooty .gid]+[winfo height .gid]/2-[winfo height $w]/2]
        
        wm geom $initwind +$x+$y
        wm transient $initwind .gid    
        
        InitWindow $w [_ "Kratos Multiphysics"] Kratos "" "" 1
        set initwind $w
        ttk::frame $w.top
        ttk::label $w.top.title_text -text [_ " Dimension selection"]
        
        ttk::frame $w.information  -relief ridge
        set i 0
        foreach dim $::Model::ValidSpatialDimensions {
            set imagepath [getImagePathDim $dim]
            if {![file exists $imagepath]} {set imagepath [file nativename [file join $dir images "$dim.png"]]}
            set img [gid_themes::GetImageModule $imagepath ""]
            set but [ttk::button $w.information.img$dim -image $img -command [list spdAux::SwitchDimAndCreateWindow $dim] ]
            
            grid $w.information.img$dim -column $i -row 0
            incr i
        }
        grid $w.top
        grid $w.top.title_text
        
        grid $w.information
    }
    
}

proc spdAux::SetSpatialDimmension {ndim} {
    
    set root [customlib::GetBaseRoot]
    set ::Model::SpatialDimension $ndim
    
    set nd [$root selectNodes "value\[@n='nDim'\]"]
    
    $nd setAttribute v $::Model::SpatialDimension
}

proc spdAux::SwitchDimAndCreateWindow { ndim } {
    variable TreeVisibility
    variable ProjectIsNew

    SetSpatialDimmension $ndim
    spdAux::DestroyWindow
    
    processIncludes
    parseRoutes
    
    apps::ExecuteOnCurrentXML MultiAppEvent init
    
    if { $ProjectIsNew eq 0} {
        spdAux::CustomTreeCommon
        apps::ExecuteOnCurrentXML CustomTree ""
    }

    if {$TreeVisibility} {
        customlib::UpdateDocument
        spdAux::PreChargeTree
        spdAux::TryRefreshTree
        spdAux::OpenTree
    }
    ::Kratos::CreatePreprocessModelTBar
}

proc spdAux::CustomTreeCommon { } {
    set AppUsesIntervals [apps::ExecuteOnCurrentApp GetAttribute UseIntervals]
    
    if {$AppUsesIntervals eq ""} {set AppUsesIntervals 0}
    if {!$AppUsesIntervals} {
        if {[getRoute Intervals] ne ""} {
            catch {spdAux::SetValueOnTreeItem state hidden Intervals}
        }
    }
    
}

proc spdAux::ForceExtremeLoad { } {
    
    set root [customlib::GetBaseRoot]
    foreach contNode [$root getElementsByTagName "container"] {
        W "Opening [$contNode  @n]"
        $contNode setAttribute tree_state "open"
    }
    gid_groups_conds::actualize_conditions_window
}

proc spdAux::getImagePathDim { dim } {
    set imagepath ""
    set imagepath [apps::getImgPathFrom [apps::getActiveAppId] "$dim.gif"]
    if {[file exists $imagepath]} {return $imagepath}
    set imagepath [apps::getImgPathFrom [apps::getActiveAppId] "$dim.png"]
    if {[file exists $imagepath]} {return $imagepath}
    set imagepath [file nativename [file join $::Model::dir images "$dim.png"] ]
    return $imagepath
}
proc spdAux::DestroyWindow {} {
    variable initwind
    if {[winfo exists $initwind]} {destroy $initwind}
}

# Routes
proc spdAux::getRoute {name} {
    variable uniqueNames
    set v ""
    if {[dict exists $uniqueNames $name]} {
        set v [dict get $uniqueNames $name]
    }
    return $v
}
proc spdAux::setRoute {name route} {
    variable uniqueNames
    #if {[dict exists $uniqueNames $name]} {W "Warning: Unique name $name already exists.\n    Previous value: [dict get $uniqueNames $name],\n    Updated value: $route"}
    set uniqueNames [dict set uniqueNames $name $route]
    set uniqueNames [dict remove $uniqueNames dummy]
    #W "Add $name $route"
    # 
    # set root [customlib::GetBaseRoot]
    # W "checking [[$root selectNodes $route] asXML]"
}

proc spdAux::parseRoutes { } {
    set root [customlib::GetBaseRoot]
    parseRecurse $root
}

proc spdAux::parseRecurse { root } {
    foreach node [$root childNodes] {
        if {[$node nodeType] eq "ELEMENT_NODE"} {
            if {[$node hasAttribute un]} {
                foreach u [split [$node getAttribute un] ","] {
                    setRoute $u [$node toXPath]
                }
            }
            if {[$node hasChildNodes]} {
                parseRecurse $node
            }
        }
    }
}


proc spdAux::ExploreAllRoutes { } {
    variable uniqueNames
    
    set root [customlib::GetBaseRoot]
    W [dict keys $uniqueNames]
    foreach routeName [dict keys $uniqueNames] {
        set route [getRoute $routeName]
        W "Route $routeName $route"
        set node [$root selectNodes $route]
        W "Node $node"
    }
    
}

proc spdAux::GetAppIdFromNode {domNode} {
    set prefix ""
    set prevDomNodeName ""
    while {$prefix eq "" && [$domNode @n] != $prevDomNodeName} {
        set prevDomNode [$domNode @n]
        set domNode [$domNode parent]
        if {[$domNode hasAttribute prefix]} {set prefix [$domNode @prefix]}
    }
    return [$domNode @n]
}

# Dependencies
proc spdAux::insertDependencies { baseNode originUN } {
    
    set root [customlib::GetBaseRoot]
    
    set originxpath [$baseNode toXPath]
    set insertxpath [getRoute $originUN]
    set insertonnode [$root selectNodes $insertxpath]
    # a lo bestia, cambiar cuando sepamos inyectar la dependencia, abajo esta a medias
    $insertonnode setAttribute "actualize_tree" 1
    
    ## Aun no soy capaz de insertar y que funcione
    #set ready 1
    #foreach c [$insertonnode getElementsByTagName "dependencies"] {
        #    if {[$c getAttribute "node"] eq $originxpath} {set ready 0; break}
        #}
    #
    #if {$ready} {
        #    set str "<dependencies node='$originxpath' actualize='1'/>"
        #    W $str
        #    W $insertxpath
        #    $insertonnode appendChild [[dom parse $str] documentElement]
        #    W [$insertonnode asXML]
        #}
}
proc spdAux::insertDependenciesSoft { originxpath relativepath n attn attv} {
    
    set root [customlib::GetBaseRoot]
    set insertonnode [$root selectNodes $originxpath]
    
    # Aun no soy capaz de insertar y que funcione
    set ready 1
    foreach c [$insertonnode getElementsByTagName "dependencies"] {
        if {[$c getAttribute "node"] eq $originxpath} {set ready 0; break}
    }
    if {$ready} {
        set str "<dependencies n='$n' node='$relativepath' att1='$attn' v1='$attv' actualize='1'/>"
        $insertonnode appendChild [[dom parse $str] documentElement]
    }
}

proc spdAux::CheckSolverEntryState {domNode} {
    set appid [GetAppIdFromNode $domNode]
    set kw [apps::getAppUniqueName $appid SolStrat]
    set nodo [$domNode selectNodes [getRoute $kw]]
    get_domnode_attribute $nodo dict
    set currentSolStrat [get_domnode_attribute $nodo v]
    set mySolStrat [get_domnode_attribute $domNode solstratname]
    return [expr [string compare $currentSolStrat $mySolStrat] == 0]
}

proc spdAux::chk_loads_function_time { domNode load_name } {
    set loads [list [list scalar]]
    lappend loads [list interpolator_func x x T]
    return [join $loads ,]
}

proc spdAux::ViewDoc {} {
    W [[customlib::GetBaseRoot] asXML]
}


proc spdAux::ConvertAllUniqueNames {oldPrefix newPrefix} {
    variable uniqueNames
    set root [customlib::GetBaseRoot]
    
    foreach routeName [dict keys $uniqueNames] {
        if {[string first $oldPrefix $routeName] eq 0} {
            set route [getRoute $routeName]
            set newrouteName [string map [list $oldPrefix $newPrefix] $routeName]
            set node [$root selectNodes $route]
            set uns [split [get_domnode_attribute $node un] ","]
            if {$newrouteName ni $uns} {
                lappend uns $newrouteName
                $node setAttribute un [ListToValues $uns]
            }
        }
    }
    
    spdAux::parseRoutes
}

# Modify the tree: field newValue UniqueName OptionalChild
proc spdAux::SetValueOnTreeItem { field value name {it "" } } {
    
    set root [customlib::GetBaseRoot]
    #W "$field $value $name $it"
    set node ""
    
    set xp [getRoute $name]
    if {$xp ne ""} {
        set node [$root selectNodes $xp]
        if {$it ne ""} {set node [$node find n $it]}
    }
    
    if {$node ne ""} {
        gid_groups_conds::setAttributes [$node toXPath] [list $field $value]
    } {
        W "$name $it not found - Check GetFromXML.tcl file"
    }
}

proc spdAux::ListToValues {lista} {
    set res ""
    foreach elem $lista {
        append res $elem
        append res ","
    }
    return [string range $res 0 end-1]
}

proc spdAux::injectSolvers {basenode args} {
    
    # Get all solvers params
    set paramspuestos [list ]
    set paramsnodes ""
    set params [::Model::GetAllSolversParams]
    foreach {parname par} $params {
        if {$parname ni $paramspuestos} {
            lappend paramspuestos $parname
            set pn [$par getPublicName]
            set type [$par getType]
            set dv [$par getDv]
            if {$dv ni [list "1" "0"]} {
                if {[write::isBooleanFalse $dv]} {set dv No}
                if {[write::isBooleanTrue $dv]} {set dv Yes}  
            }
            append paramsnodes "<value n='$parname' pn='$pn' state='\[SolverParamState\]' v='$dv' "
            if {$type eq "bool"} {
                append paramsnodes " values='Yes,No' "
            }
            if {$type eq "combo"} {
                append paramsnodes " values='\[GetSolverParameterValues\]' "
                append paramsnodes " dict='\[GetSolverParameterDict\]' "
            }
            
            append paramsnodes "/>"
        }
    }
    set contnode [$basenode parent]
    
    # Get All SolversEntry
    set ses [list ]
    foreach st [::Model::GetSolutionStrategies {*}$args] {
        lappend ses $st [$st getSolversEntries]
    }
    
    # One container per solverEntry 
    foreach {st ss} $ses {
        foreach se $ss {
            set stn [$st getName]
            set n [$se getName]
            set pn [$se getPublicName]
            set help [$se getHelp]
            set appid [GetAppIdFromNode [$basenode parent]]
            set un [apps::getAppUniqueName $appid "$stn$n"]
            set container "<container help='$help' n='$n' pn='$pn' un='$un' state='\[SolverEntryState\]' solstratname='$stn' open_window='0' icon='solver'>"
            set defsolver [lindex [$se getDefaultSolvers] 0]
            append container "<value n='Solver' pn='Solver' v='$defsolver' values='\[GetSolversValues\]' dict='\[GetSolvers\]' actualize='1' update_proc='UpdateTree'/>"
            #append container "<dependencies node='../value' actualize='1'/>"
            #append container "</value>"
            append container $paramsnodes
            append container "</container>"
            $contnode appendXML $container
        }
    }
    $basenode delete
}

proc spdAux::injectSolStratParams {basenode args} {
    set contnode [$basenode parent]
    set params [::Model::GetSolStratParams {*}$args]
    foreach {parname par} $params {
        #W "$parname [$contnode find n $parname]"
        if {[$contnode find n $parname] eq ""} {
            set pn [$par getPublicName]
            set type [$par getType]
            set dv [$par getDv]
            if {$type eq "bool"} {set dv [GetBooleanForTree $dv]}
            set helptext [$par getHelp]
            set actualize [$par getActualize]
            set node "<value n='$parname' pn='$pn' state='\[SolStratParamState\]' v='$dv' help='$helptext' "
            
            if {$actualize} {
                append node "actualize_tree='1'"
            }
            
            if {$type eq "bool"} {
                
                append node " values='Yes,No' "
            }
            if {$type eq "combo"} {
                set values [$par getValues]
                set vs [join [$par getValues] ,]
                set pvalues [$par getPValues]
                
                set pv ""
                for {set i 0} {$i < [llength $values]} {incr i} {
                    lappend pv [lindex $values $i]
                    lappend pv [lindex $pvalues $i] 
                }
                set pv [join $pv ,]
                #W " values='$vs' dict='$pv' "
                append node " values='$vs' dict='$pv' "
            } 
            append node "/>"
            
            $contnode appendXML $node
            set orig [$contnode lastChild]
            set new [$orig cloneNode]
            $orig delete
            $contnode insertBefore $new $basenode
        }
    }
    
    set params [::Model::GetSchemesParams {*}$args]
    
    foreach {parname par} $params {
        #W "$parname [$contnode find n $parname]"
        if {[$contnode find n $parname] eq ""} {
            set pn [$par getPublicName]
            set type [$par getType]
            set dv [$par getDv]
            if {$type eq "bool"} {set dv [GetBooleanForTree $dv]}
            set helptext [$par getHelp]
            set node "<value n='$parname' pn='$pn' state='\[SchemeParamState\]' v='$dv' help='$helptext' "
            if {$type eq "bool"} {
                append node " values='Yes,No' "
            } 
            append node "/>"
            $contnode appendXML $node
        }
    }
    $basenode delete
}



proc spdAux::injectNodalConditions { basenode args} {
    if {$args eq "{}"} {
        set nodal_conditions [::Model::getAllNodalConditions]
    } {
        set nodal_conditions [::Model::GetNodalConditions {*}$args]
    }
    spdAux::_injectCondsToTree $basenode $nodal_conditions "nodal"
    $basenode delete
}

proc spdAux::injectConditions { basenode args} {
    set conditions [::Model::GetConditions {*}$args]
    spdAux::_injectCondsToTree $basenode $conditions
    $basenode delete
}

proc spdAux::_injectCondsToTree {basenode cond_list {cond_type "normal"} } {
    set conds [$basenode parent]
    set AppUsesIntervals [apps::ExecuteOnApp [GetAppIdFromNode $conds] GetAttribute UseIntervals]
    if {$AppUsesIntervals eq ""} {set AppUsesIntervals 0}
    
    foreach cnd $cond_list {
        set n [$cnd getName]
        set pn [$cnd getPublicName]
        set help [$cnd getHelp]
        set etype ""
        if {$cond_type eq "nodal"} {
            set etype [$cnd getOv]
        } else {
            set etype [join [string tolower [$cnd getAttribute ElementType]] ,]
        }
        if {$etype eq ""} {
            if {$::Model::SpatialDimension eq "3D"} {
                set etype "point,line,surface,volume"
            } else {
                set etype "point,line,surface"
            }
        }
        set units [$cnd getAttribute "units"]
        set um [$cnd getAttribute "unit_magnitude"]
        set processName [$cnd getProcessName]

        set process [::Model::GetProcess $processName]
        if {$process eq ""} {error [= "Condition %s can't find its process: %s" $n $processName]}
        set check [$process getAttribute "check"]
        if {$check eq ""} {set check "UpdateTree"}
        set state "ConditionState"
        if {$cond_type eq "nodal"} {
            set state [$cnd getAttribute state]
            if {$state eq ""} {set state "CheckNodalConditionState"}
        }
        set node "<condition n='$n' pn='$pn' ov='$etype' ovm='' icon='shells16' help='$help' state='\[$state\]' update_proc='\[OkNewCondition\]' check='$check'>"
        set inputs [concat [$process getInputs] [$cnd getInputs] ]
        foreach {inName in} $inputs {
            set forcedParams [list cnd_v [$cnd getDefault $inName v] n $n units $units um $um base $process]
            foreach key [$cnd getDefaults $inName] {
                lappend forcedParams $key [$cnd getDefault $inName $key]
            }
            append node [GetParameterValueString $in $forcedParams]
        }
        set CondUsesIntervals [$cnd getAttribute "Interval"]
        if {$AppUsesIntervals && $CondUsesIntervals ne "False"} {
            append node "<value n='Interval' pn='Time interval' v='$CondUsesIntervals' values='\[getIntervals\]'  help='$help'/>"
        }
        append node "</condition>"
        $conds appendXML $node
    }
    
}

proc spdAux::GetParameterValueString { param {forcedParams ""}} {
    set node ""

    set inName [$param getName]
    set pn [$param getPublicName]
    set type [$param getType]
    set v [$param getDv]
    set help [$param getHelp]
    set cnd_v ""
    set base ""
    set units ""
    set um ""
    set n ""

    # set state [$in getAttribute "state"]
    # set cnd_state [$cnd getDefault $inName state]
    # if {$cnd_state ne ""} {set state $cnd_state}
    # if {$state eq ""} {set state "normal"}
    set state {[ConditionParameterState]}

    # Set forced values -> Caution when debugging
    foreach {key value} $forcedParams {
        set $key $value
    }
    if {$cnd_v ne ""} {set v $cnd_v}

    set has_units [$param getAttribute "has_units"]
    if {$has_units ne ""} { 
        set has_units "units='$units'  unit_magnitude='$um'"
    } else {
        set param_units [$param getAttribute "units"]
        set param_unitm [$param getAttribute "unit_magnitude"]
        if {$param_units ne "" && $param_unitm ne ""} {
            set has_units "units='$param_units'  unit_magnitude='$param_unitm'"
        }
    }
    if {$type eq "vector"} {
        set vector_type [$param getAttribute "vectorType"]
        lassign [split $v ","] vX vY vZ
        if {$vector_type eq "bool"} {
            set zstate "\[CheckDimension 3D\]"
            if {$state eq "hidden"} {set zstate hidden}
            append node "
                <value n='${inName}X' wn='[concat $n "_X"]' pn='X ${pn}' v='$vX' values='1,0' help='' state='$state'/>
                <value n='${inName}Y' wn='[concat $n "_Y"]' pn='Y ${pn}' v='$vY' values='1,0' help='' state='$state'/>
                <value n='${inName}Z' wn='[concat $n "_Z"]' pn='Z ${pn}' v='$vZ' values='1,0' help='' state='$zstate'/>"
        } else {
            foreach i [list "X" "Y" "Z"] {
                set fname "function_$inName"
                set nodev "../value\[@n='${inName}$i'\]"
                set nodef "../value\[@n='$i$fname'\]"
                set zstate ""
                if {$i eq "Z"} { set zstate "state='\[CheckDimension 3D\]'"}
                if {[$param getAttribute "enabled"] in [list "1" "0"]} {
                    set val [expr [$param getAttribute "enabled"] ? "Yes" : "No"]
                    #if {$i eq "Z"} { set val "No" }
                    append node "<value n='Enabled_$i' pn='$i component' v='$val' values='Yes,No'  help='Enables the $i ${inName}' $zstate >"
                    append node "<dependencies value='No' node=\""
                    append node $nodev
                    append node "\" att1='state' v1='hidden'/>"
                    append node "<dependencies value='Yes' node=\""
                    append node $nodev
                    append node "\" att1='state' v1='normal'/>"
                    if {[$param getAttribute "function"] eq "1"} {
                        set fname "${i}function_$inName"
                        set nodef "../value\[@n='$fname'\]"
                        set nodeb "../value\[@n='ByFunction$i'\]"
                        append node "<dependencies value='No' node=\""
                        append node $nodef
                        append node "\" att1='state' v1='hidden'/>"
                        append node "<dependencies value='No' node=\""
                        append node $nodeb
                        append node "\" att1='state' v1='hidden'/>"
                        append node "<dependencies value='Yes' node=\""
                        append node $nodeb
                        append node "\" att1='state' v1='normal'/>"
                    }
                    append node "</value>"
                }
                if {[$param getAttribute "function"] eq "1"} {
                    set fname "${i}function_$inName"
                    append node "<value n='ByFunction$i' pn='by function -> f(x,y,z,t)' v='No' values='Yes,No'  actualize_tree='1'  $zstate >
                        <dependencies value='No' node=\""
                    append node $nodev
                    append node "\" att1='state' v1='normal'/>
                        <dependencies value='Yes'  node=\""
                    append node $nodev
                    append node "\" att1='state' v1='hidden'/>
                        <dependencies value='No' node=\""
                    append node $nodef
                    append node "\" att1='state' v1='hidden'/>
                        <dependencies value='Yes'  node=\""
                    append node $nodef
                    append node "\" att1='state' v1='normal'/>
                        </value>"
                    append node "<value n='$fname' pn='$i function' v='' help='$help'  $zstate />"
                }
                set v "v$i"
                if { $vector_type eq "file" || $vector_type eq "tablefile" } {
                    if {[set $v] eq ""} {set $v "- No file"}
                    append node "<value n='${inName}$i' wn='[concat $n "_$i"]' pn='$i ${pn}' v='[set $v]' values='\[GetFilesValues\]' update_proc='AddFile' help='$help'  $zstate  type='$vector_type'/>"
                } else {
                    append node "<value n='${inName}$i' wn='[concat $n "_$i"]' pn='$i ${pn}' v='[set $v]' $has_units help='$help'  $zstate />"
                }
            }
        }
        
    } elseif { $type eq "combo" } {
        set values [$param getValues]
        set pvalues [$param getPValues]
        set pv ""
        for {set i 0} {$i < [llength $values]} {incr i} {
            lappend pv [lindex $values $i]
            lappend pv [lindex $pvalues $i] 
        }
        set values [join [$param getValues] ","]
        set pvalues [join $pv ","]
        append node "<value n='$inName' pn='$pn' v='$v' values='$values'"
        if {[llength $pv]} {
            append node " dict='$pvalues' "
        }
        if {[$param getActualize]} {
            append node "  actualize_tree='1'  "
        }
        append node " state='$state' help='$help'>"
        if {$base ne ""} { append node [_insert_cond_param_dependencies $base $inName] }
        append node "</value>"
    } elseif { $type eq "bool" } {
        set values "1,0"
        append node "<value n='$inName' pn='$pn' v='$v' values='$values'  help='$help'"
        if {[$param getActualize]} {
            append node "  actualize_tree='1'  "
        }
        append node " state='$state'>"
        if {$base ne ""} {append node [_insert_cond_param_dependencies $base $inName]}
        append node "</value>"
    } elseif { $type eq "file" || $type eq "tablefile" } {
        append node "<value n='$inName' pn='$pn' v='$v' values='\[GetFilesValues\]' update_proc='AddFile' help='$help' state='$state' type='$type'/>"
    } elseif { $type eq "integer" } {
        append node "<value n='$inName' pn='$pn' v='$v' $has_units  help='$help' string_is='integer'/>"
    } else {
        if {[$param getAttribute "function"] eq "1"} {
            set fname "function_$inName"
            set nodev "../value\[@n='$inName'\]"
            set nodef "../value\[@n='$fname'\]"
            append node "<value n='ByFunction' pn='by function -> f(x,y,z,t)' v='No' values='Yes,No'  actualize_tree='1' state='$state'>
                <dependencies value='No' node=\""
            append node $nodev
            append node "\" att1='state' v1='normal'/>
                <dependencies value='Yes'  node=\""
            append node $nodev
            append node "\" att1='state' v1='hidden'/>
                <dependencies value='No' node=\""
            append node $nodef
            append node "\" att1='state' v1='hidden'/>
                <dependencies value='Yes'  node=\""
            append node $nodef
            append node "\" att1='state' v1='normal'/>
                </value>"
            
            append node "<value n='$fname' pn='Function' v='' help='$help'  state='$state'/>"
        }
        append node "<value n='$inName' pn='$pn' v='$v' $has_units  help='$help' string_is='double'  state='$state'/>"
    }
    return $node
}

proc spdAux::_insert_cond_param_dependencies {base param_name} {
    set dep_list [list ]
    foreach {pn param} [$base getInputs] {
        if {[$param getDepN] eq $param_name} {
            lappend dep_list [$param getName] [$param getDepV]
        }
    }
    set ret ""
    foreach {name value} $dep_list {
        set nodev "../value\[@n='$name'\]"
        append ret " <dependencies value='$value' node=\""
                    append ret $nodev
                    append ret "\"  att1='state' v1='normal'/>"
        append ret " <dependencies condition=\"@v!='$value'\" node=\""
                    append ret $nodev
                    append ret "\"  att1='state' v1='hidden'/>"
    }
    return $ret
}
proc spdAux::injectPartInputs { basenode {inputs ""} } {
    set base [$basenode parent]
    set processeds [list ]
    spdAux::injectLocalAxesButton $basenode
    foreach obj [concat [Model::GetElements] [Model::GetConstitutiveLaws]] {
        set inputs [$obj getInputs]
        foreach {inName in} $inputs {
            if {$inName ni $processeds} {
                lappend processeds $inName
                set forcedParams [list state {[PartParamState]} ]
                if {[$in getActualize]} { lappend forcedParams base $obj }
                set node [GetParameterValueString $in $forcedParams]
                
                $base appendXML $node
                set orig [$base lastChild]
                set new [$orig cloneNode -deep]
                $orig delete
                $base insertBefore $new $basenode
            }
        }
    }
    $basenode delete
}

proc spdAux::injectMaterials { basenode args } {
    set base [$basenode parent]
    set materials [Model::GetMaterials {*}$args]
    foreach mat $materials {
        set matname [$mat getName]
        set mathelp [$mat getAttribute help]
        set inputs [$mat getInputs]
        set matnode "<blockdata n='material' name='$matname' sequence='1' editable_name='unique' icon='material16' help='Material definition'>"
        foreach {inName in} $inputs {
            set node [spdAux::GetParameterValueString $in [list base $mat state [$in getAttribute state]]]
            append matnode $node
        }
        append matnode "</blockdata> \n"
        $base appendXML $matnode
    }
    $basenode delete
}

proc spdAux::injectLocalAxesButton { basenode } {
    # set base [$basenode parent]
    # set node "<value n='Local_axes' pn='Local axes' v='Automatic' values='Automatic' editable='0' local_axes='disabled' help='If the direction to define is not coincident with the global axes, it is possible to define a set of local axes and prescribe the displacements related to that local axes'>
    # <dependencies node='.' att1='local_axes' v1='normal' value='1'/>
    # <dependencies node='.' att1='local_axes' v1='disabled' not_value='1'/>
    # </value>"
    # $base appendXML $node
    # W [$base asXML]
    
    
    # GiD_Process MEscape Data Conditions AssignCond line_Local_axes change -Automatic- 1 escape escape 

}

proc spdAux::injectElementOutputs { basenode args} {
    set args {*}$args
    return [spdAux::injectElementOutputs_do $basenode $args]
}
proc spdAux::injectElementOutputs_do { basenode args} {
    set base [$basenode parent]
    set args {*}$args

    set outputs [::Model::GetAllElemOutputs $args]
    foreach in [dict keys $outputs] {
        set pn [[dict get $outputs $in] getPublicName]
        set v [GetBooleanForTree [[dict get $outputs $in] getDv]]
        
        set node "<value n='$in' pn='$pn' state='\[ElementOutputState\]' v='$v' values='Yes,No' />"
        
        $base appendXML $node
        set orig [$base lastChild]
        set new [$orig cloneNode]
        $orig delete
        $base insertBefore $new $basenode
        
    }
    $basenode delete
}

proc spdAux::injectNodalConditionsOutputs { basenode args} {
    set args {*}$args
    return [spdAux::injectNodalConditionsOutputs_do $basenode $args]
}
proc spdAux::injectNodalConditionsOutputs_do { basenode args} {
    set base [$basenode parent]
    set args {*}$args

    if {$args eq ""} {
        set nodal_conditions [::Model::getAllNodalConditions]
    } {
        set nodal_conditions [::Model::GetNodalConditions $args]
    }
    foreach nc $nodal_conditions {
        set n [$nc getName]
        set pn [$nc getPublicName]
        set v [$nc getAttribute v]
        if {$v eq ""} {set v "Yes"}

        set state [$nc getAttribute state]
        if {$state eq ""} {set state "CheckNodalConditionState"}
        set node "<value n='$n' pn='$pn' v='$v' values='Yes,No' state='\[$state $n\]'/>"
        $base appendXML $node
        foreach {n1 output} [$nc getOutputs] {
            set nout [$output getName]
            set pn [$output getPublicName]
            set v [$output getAttribute v]
            if {$v eq ""} {set v "Yes"}
            set node "<value n='$nout' pn='$pn' v='$v' values='Yes,No' state='\[CheckNodalConditionOutputState $n\]'/>"
            $base appendXML $node
        }
    }
    $basenode delete
}

proc spdAux::GetBooleanForTree {raw} {
    set goodList [list "Yes" "1" "yes" "ok" "YES" "Ok" "True" "TRUE" "true"]
    if {$raw in $goodList} {return "Yes" } {return "No"}
}

proc spdAux::injectConstitutiveLawOutputs { tempnode  args} {
    set basenode [$tempnode parent]
    set outputs [::Model::GetAllCLOutputs {*}$args]
    foreach in [dict keys $outputs] {
        if {[$basenode find n $in] eq ""} {
            set pn [[dict get $outputs $in] getPublicName]
            set v [GetBooleanForTree [[dict get $outputs $in] getDv]]
            set node "<value n='$in' pn='$pn' state='\[ConstLawOutputState\]' v='$v' values='Yes,No' />"
            $basenode appendXML $node
            set orig [$basenode lastChild]
            set new [$orig cloneNode]
            $orig delete
            $basenode insertBefore $new $tempnode
        }
    }
    $tempnode delete
}

proc spdAux::injectProcs { basenode  args} {
    set appId [apps::getActiveAppId]
    if {$appId ne ""} {
        set f "::$appId"
        append f "::dir"
        set nf [file join [subst $$f] xml Procs.spd]
        set xml [tDOM::xmlReadFile $nf]
        set newnode [dom parse [string trim $xml]]
        set xmlNode [$newnode documentElement]
        
        foreach in [$xmlNode getElementsByTagName "proc"] {
            # This allows an app to overwrite mandatory procs
            set procn [$in @n]
            set pastnode [[$basenode parent] selectNodes "./proc\[@n='$procn'\]"]
            if {$pastnode ne ""} {gid_groups_conds::delete [$pastnode toXPath]}
            
            [$basenode parent] appendChild $in
        }
        $basenode delete
    }
}

proc spdAux::CheckConstLawOutputState {outnode} {
    
    set root [customlib::GetBaseRoot]
    
    set nodeApp [GetAppIdFromNode $outnode]
    set parts_un [apps::getAppUniqueName $nodeApp Parts]
    set parts_path [getRoute $parts_un]
    set xp1 "$parts_path/group/value\[@n='ConstitutiveLaw'\]"
    set constlawactive [list ]
    foreach gNode [$root selectNodes $xp1] {
        lappend constlawactive [get_domnode_attribute $gNode v]
    }
    
    set paramName [$outnode @n]
    return [::Model::CheckConstLawOutputState $constlawactive $paramName]
}

proc spdAux::CheckElementOutputState {outnode} {
    
    set root [customlib::GetBaseRoot]
    
    set nodeApp [GetAppIdFromNode $outnode]
    set parts_un [apps::getAppUniqueName $nodeApp Parts]
    set parts_path [getRoute $parts_un]
    set xp1 "$parts_path/group/value\[@n='Element'\]"
    set elemsactive [list ]
    foreach gNode [$root selectNodes $xp1] {
        lappend elemsactive [get_domnode_attribute $gNode v]
    }
    set paramName [$outnode @n]
    return [::Model::CheckElementOutputState $elemsactive $paramName]
}

proc spdAux::SolStratParamState {outnode} {
    
    set root [customlib::GetBaseRoot]
    set nodeApp [GetAppIdFromNode $outnode]
    
    set sol_stratUN [apps::getAppUniqueName $nodeApp SolStrat]
    
    if {[get_domnode_attribute [$root selectNodes [spdAux::getRoute $sol_stratUN]] v] eq ""} {
        get_domnode_attribute [$root selectNodes [spdAux::getRoute $sol_stratUN]] dict
    }
    set SolStrat [::write::getValue $sol_stratUN]
    
    set paramName [$outnode @n]
    set ret [::Model::CheckSolStratInputState $SolStrat $paramName]
    if {$ret} {
        lassign [Model::GetSolStratParamDep $SolStrat $paramName] depN depV
        foreach node [[$outnode parent] childNodes] {
            if {[$node @n] eq $depN} {
                if {[get_domnode_attribute $node v] ni [split $depV ,]} {
                    set ret 0
                    break
                }
            }
        }
    }
    return $ret
}

proc spdAux::SchemeParamState {outnode} {
    
    set root [customlib::GetBaseRoot]
    set nodeApp [GetAppIdFromNode $outnode]
    
    set sol_stratUN [apps::getAppUniqueName $nodeApp SolStrat]
    set schemeUN [apps::getAppUniqueName $nodeApp Scheme]
    
    if {[get_domnode_attribute [$root selectNodes [spdAux::getRoute $sol_stratUN]] v] eq ""} {
        get_domnode_attribute [$root selectNodes [spdAux::getRoute $sol_stratUN]] dict
    }
    if {[get_domnode_attribute [$root selectNodes [spdAux::getRoute $schemeUN]] v] eq ""} {
        get_domnode_attribute [$root selectNodes [spdAux::getRoute $schemeUN]] dict
    }
    set SolStrat [::write::getValue $sol_stratUN]
    set Scheme [write::getValue $schemeUN]
    
    set paramName [$outnode @n]
    return [::Model::CheckSchemeInputState $SolStrat $Scheme $paramName]
}

proc spdAux::getIntervals { {un "Intervals"} } {
    set root [customlib::GetBaseRoot]

    set xp1 "[spdAux::getRoute $un]/blockdata\[@n='Interval'\]"
    set lista [list ]
    foreach node [$root selectNodes $xp1] {
        lappend lista [$node @name]
    }
    
    return $lista
}

proc spdAux::CreateInterval {name ini end {un "Intervals"}} {
    if {$name in [getIntervals $un]} {error [= "Interval %s already exists" $name]}
    set root [customlib::GetBaseRoot]
    set interval_path [spdAux::getRoute $un]
    
    set interval_string "<blockdata n='Interval' pn='Interval' name='$name' sequence='1' editable_name='unique' sequence_type='non_void_disabled' help='Interval'>
        <value n='IniTime' pn='Start time' v='$ini' help='When do the interval starts?'/>
        <value n='EndTime' pn='End time' v='$end' help='When do the interval ends?'/>
    </blockdata>"
    [$root selectNodes $interval_path] appendXML $interval_string
}

proc spdAux::getTimeFunctions {} {
    
    set root [customlib::GetBaseRoot]
    set functions_un [apps::getCurrentUniqueName Functions]
    set xp1 "[spdAux::getRoute $functions_un]/blockdata\[@n='Function'\]"
    set lista [list ]
    foreach node [$root selectNodes $xp1] {
        lappend lista [$node @name]
    }
    
    return $lista
}

proc spdAux::getFields {} {
    
    set root [customlib::GetBaseRoot]
    set fields_un [apps::getCurrentUniqueName Fields]
    set xp1 "[spdAux::getRoute $fields_un]/blockdata\[@n='Field'\]"
    set lista [list ]
    foreach node [$root selectNodes $xp1] {
        lappend lista [$node @name]
    }
    
    return $lista
}


spdAux::Init

############# procs #################
proc spdAux::ProcGetElements { domNode args } {
    set nodeApp [GetAppIdFromNode $domNode]
    set sol_stratUN [apps::getAppUniqueName $nodeApp SolStrat]
    set schemeUN [apps::getAppUniqueName $nodeApp Scheme]
    if {[get_domnode_attribute [$domNode selectNodes [spdAux::getRoute $sol_stratUN]] v] eq ""} {
        get_domnode_attribute [$domNode selectNodes [spdAux::getRoute $sol_stratUN]] dict
    }
    if {[get_domnode_attribute [$domNode selectNodes [spdAux::getRoute $schemeUN]] v] eq ""} {
        get_domnode_attribute [$domNode selectNodes [spdAux::getRoute $schemeUN]] dict
    }
    
    #W "solStrat $sol_stratUN sch $schemeUN"
    set solStratName [::write::getValue $sol_stratUN]
    set schemeName [write::getValue $schemeUN]
    #W "$solStratName $schemeName"
    #W "************************************************************************"
    #W "$nodeApp $solStratName $schemeName"
    set elems [::Model::GetAvailableElements $solStratName $schemeName]
    #W "************************************************************************"
    set names [list ]
    set pnames [list ]
    foreach elem $elems {
        if {[$elem cumple {*}$args]} {
            lappend names [$elem getName]
            lappend pnames [$elem getName] 
            lappend pnames [$elem getPublicName]
        }
    }
    set diction [join $pnames ","]
    set values [join $names ","]
    #W "[get_domnode_attribute $domNode v] $names"
    $domNode setAttribute values $values
    if {[get_domnode_attribute $domNode v] eq ""} {$domNode setAttribute v [lindex $names 0]}
    if {[get_domnode_attribute $domNode v] ni $names} {$domNode setAttribute v [lindex $names 0]; spdAux::RequestRefresh}
    #spdAux::RequestRefresh
    return $diction
}

proc spdAux::ProcGetElementsValues { domNode args } {
    set nodeApp [GetAppIdFromNode $domNode]
    set sol_stratUN [apps::getAppUniqueName $nodeApp SolStrat]
    set schemeUN [apps::getAppUniqueName $nodeApp Scheme]
    if {[get_domnode_attribute [$domNode selectNodes [spdAux::getRoute $sol_stratUN]] v] eq ""} {
        get_domnode_attribute [$domNode selectNodes [spdAux::getRoute $sol_stratUN]] dict
    }
    if {[get_domnode_attribute [$domNode selectNodes [spdAux::getRoute $schemeUN]] v] eq ""} {
        get_domnode_attribute [$domNode selectNodes [spdAux::getRoute $schemeUN]] dict
    }
    
    set solStratName [::write::getValue $sol_stratUN]
    set schemeName [write::getValue $schemeUN]
    set elems [::Model::GetAvailableElements $solStratName $schemeName]
    
    set names [list ]
    foreach elem $elems {
        if {[$elem cumple {*}$args]} {
            lappend names [$elem getName]
        }
    }
    if {[get_domnode_attribute $domNode v] eq ""} {$domNode setAttribute v [lindex $names 0]}
    if {[get_domnode_attribute $domNode v] ni $names} {$domNode setAttribute v [lindex $names 0]; spdAux::RequestRefresh}
    set values [join $names ","]
    return $values
}

proc spdAux::ProcGetElementsDict { domNode args } {
    set elems [Model::GetElements]
    set pnames [list ]
    foreach elem $elems {
        lappend pnames [$elem getName] 
        lappend pnames [$elem getPublicName]
    }
    set diction [join $pnames ","]
    return $diction
}

proc spdAux::ProcGetSolutionStrategies {domNode args} {
    set names [list ]
    set pnames [list ]
    #W $args
    set Sols [::Model::GetSolutionStrategies {*}$args]
    #W $Sols
    foreach ss $Sols {
        lappend names [$ss getName]
        lappend pnames [$ss getName]
        lappend pnames [$ss getPublicName] 
    }
    
    $domNode setAttribute values [join $names ","]
    set dv [lindex $names 0]
    #W "dv $dv"
    if {[$domNode getAttribute v] eq ""} {$domNode setAttribute v $dv; spdAux::RequestRefresh}
    if {[$domNode getAttribute v] ni $names} {$domNode setAttribute v $dv; spdAux::RequestRefresh}
    
    return [join $pnames ","]
}

proc spdAux::ProcGetSchemes {domNode args} {
    set nodeApp [GetAppIdFromNode $domNode]
    #W $nodeApp
    set sol_stratUN [apps::getAppUniqueName $nodeApp SolStrat]
    set sol_stat_path [spdAux::getRoute $sol_stratUN]
    
    if {[get_domnode_attribute [$domNode selectNodes $sol_stat_path] v] eq ""} {
        #W "entra"
        get_domnode_attribute [$domNode selectNodes $sol_stat_path] dict
        get_domnode_attribute [$domNode selectNodes $sol_stat_path] values
    }
    set solStratName [::write::getValue $sol_stratUN]
    #W "Unique name: $sol_stratUN - Nombre $solStratName"
    set schemes [::Model::GetAvailableSchemes $solStratName]
    
    set ids [list ]
    if {[llength $schemes] == 0} {
        if {[get_domnode_attribute $domNode v] eq ""} {$domNode setAttribute v "None"}
        return "None"
    }
    set names [list ]
    set pnames [list ]
    foreach cl $schemes {
        lappend names [$cl getName]
        lappend pnames [$cl getName] 
        lappend pnames [$cl getPublicName]
    }
    
    $domNode setAttribute values [join $names ","]
    
    if {[get_domnode_attribute $domNode v] eq ""} {$domNode setAttribute v [lindex $names 0]}
    if {[get_domnode_attribute $domNode v] ni $names} {$domNode setAttribute v [lindex $names 0]}
    spdAux::RequestRefresh
    return [join $pnames ","]
}

proc spdAux::SetNoneValue {domNode} {
    $domNode setAttribute v "None"
    #$domNode setAttribute values "None"
    #spdAux::RequestRefresh
    return "None,None"
}

#This should go to values
proc spdAux::ProcGetConstitutiveLaws { domNode args } {
    set Elementname [$domNode selectNodes {string(../value[@n='Element']/@v)}]
    set Claws [::Model::GetAvailableConstitutiveLaws $Elementname]
    #W "Const Laws que han pasado la criba: $Claws"
    if {[llength $Claws] == 0} { return None }
    set names [list ]
    foreach cl $Claws {
        lappend names [$cl getName]
    }
    set values [join $names ","]
    if {[get_domnode_attribute $domNode v] eq "" || [get_domnode_attribute $domNode v] ni $names} {$domNode setAttribute v [lindex $names 0]; spdAux::RequestRefresh}
    #spdAux::RequestRefresh
    
    return $values
}
#This should go to dict
proc spdAux::ProcGetAllConstitutiveLaws { domNode args } {
    set Claws [Model::GetConstitutiveLaws]
    if {[llength $Claws] == 0} { return [SetNoneValue $domNode] }
    set pnames [list ]
    foreach cl $Claws {
        lappend pnames [$cl getName] 
        lappend pnames [$cl getPublicName]
    }
    set diction [join $pnames ","]
    #spdAux::RequestRefresh
    
    return $diction
}
proc spdAux::ProcGetSolvers { domNode args } {
    
    set solStrat [get_domnode_attribute [$domNode parent] solstratname]
    set solverEntryId [get_domnode_attribute [$domNode parent] n]
    
    set solvers [Model::GetAvailableSolvers $solStrat $solverEntryId]
    
    set pnames [list ]
    foreach slvr $solvers {
        lappend pnames [$slvr getName] 
        lappend pnames [$slvr getPublicName]
    }
    return [join $pnames ","]
    
}

proc spdAux::ProcGetSolverParameterDict { domNode args } {
    set param_name [get_domnode_attribute $domNode n]
    set pnames [list ]
    foreach solver [Model::GetAllSolvers] {
        foreach param [dict values [$solver getInputs]] {
            foreach value [$param getValues] pvalue [$param getPValues] {
                if {$value ni $pnames} {
                    lappend pnames $value
                    lappend pnames $pvalue
                }
            }
        }
    }
    return [join $pnames ","]
}
proc spdAux::ProcGetSolverParameterValues { domNode args } {
    
    set solver_node [[$domNode parent] selectNodes "./value\[@n='Solver'\]"]
    #get_domnode_attribute $solver_node values
    set solver [Model::GetSolver [get_domnode_attribute $solver_node v]]
    set param_name [get_domnode_attribute $domNode n]
    set param [$solver getInputPn $param_name]
    set values [$param getValues]
    set v [get_domnode_attribute $domNode v]
    if {$v eq "" || $v ni $values} {
        set v [$param getDv]
        if {$v eq "" || $v ni $values} {
            set v [lindex $values 0]
        }
        $domNode setAttribute v $v
    }
    if {$param ne ""} {return [join $values ","]}
    return ""
}
proc spdAux::ProcGetSolversValues { domNode args } {
    
    set solStrat [get_domnode_attribute [$domNode parent] solstratname]
    set solverEntryId [get_domnode_attribute [$domNode parent] n]
    
    set solvers [Model::GetAvailableSolvers $solStrat $solverEntryId]
    
    set curr_parallel_system OpenMP
    catch {set curr_parallel_system [write::getValue ParallelType]}
    
    set names [list ]
    set pnames [list ]
    foreach slvr $solvers {
        if {[$slvr getParallelism] eq $curr_parallel_system} {
            lappend names [$slvr getName]
        }
    }
    #$domNode setAttribute values [join $names ","]
    if {[get_domnode_attribute $domNode v] eq ""} {$domNode setAttribute v [lindex $names 0]}
    return [join $names ","]
    
}

proc spdAux::ProcConditionState { domNode args } {
    
    set resp [::Model::CheckConditionState $domNode]
    if {$resp} {return "normal"} else {return "hidden"}
}

proc spdAux::ProcCheckNodalConditionState { domNode args } {
    
    set nodeApp [GetAppIdFromNode $domNode]
    set parts_un [apps::getAppUniqueName $nodeApp Parts]
    #W $parts_un
    if {[spdAux::getRoute $parts_un] ne ""} {
        set conditionId [$domNode @n]
        set elems [$domNode selectNodes "[spdAux::getRoute $parts_un]/group/value\[@n='Element'\]"]
        set elemnames [list ]
        foreach elem $elems {
            set elemName [$elem @v]
            if {$elemName eq ""} {get_domnode_attribute $elem dict; get_domnode_attribute $elem values; set elemName [$elem @v]}
            lappend elemnames $elemName
        }
        set elemnames [lsort -unique $elemnames]
        if {$elemnames eq ""} {return "hidden"}
        if {[::Model::CheckElementsNodalCondition $conditionId $elemnames]} {return "normal"} else {return "hidden"}
    } {return "normal"}
}
proc spdAux::ProcCheckNodalConditionOutputState { domNode args } {
    
    set nodeApp [GetAppIdFromNode $domNode]
    set NC_un [apps::getAppUniqueName $nodeApp NodalConditions]
    if {[spdAux::getRoute $NC_un] ne ""} {
        set ncs [$domNode selectNodes "[spdAux::getRoute $NC_un]/condition/group"]
        set ncslist [list ]
        foreach nc $ncs { lappend ncslist [[$nc parent] @n]}
        set ncslist [lsort -unique $ncslist]
        set conditionId [lindex $args 0]
        if {$conditionId ni $ncslist} {return "hidden"} {return "normal"}
        set outputId [$domNode @n]
        if {[::Model::CheckNodalConditionOutputState $conditionId $outputId]} {return "normal"} else {return "hidden"}
    } {return "normal"}
}
proc spdAux::ProcRefreshTree { domNode args } {
    spdAux::RequestRefresh
}

proc spdAux::ProccheckStateByUniqueName { domNode args } {
    set total 0
    foreach {un val} {*}$args {
        set xpath [spdAux::getRoute $un]
        if {$xpath ne ""} {
            spdAux::insertDependencies $domNode $un
            set node [$domNode selectNodes $xpath]
            set realval [get_domnode_attribute $node v]
            if {$realval eq ""} {W "Warning: Check unique name $un"}
            if {[lsearch $val $realval] != -1} {
                set total 1
                break
            }
        } else {W "Warning: Check unique name $un"}
    }
    if {$total} {return "normal"} else {return "hidden"}
}
proc spdAux::ProcSolverParamState { domNode args } {
    
    
    set id [$domNode getAttribute n]
    set nodesolver [[$domNode parent] selectNodes "./value\[@n='Solver'\]"]
    get_domnode_attribute $nodesolver values
    set solverid [get_domnode_attribute $nodesolver v]
    
    if {$solverid eq ""} {set resp 0} {
        set resp [::Model::getSolverParamState $solverid $id]
    }
    
    #spdAux::RequestRefresh
    if {$resp} {return "normal"} else {return "hidden"}
}


proc spdAux::CheckPartParamValue {node material_name} {
    
    set root [customlib::GetBaseRoot]
    #W "Searching [get_domnode_attribute $node n] $material_name"
    if {[$node hasAttribute n] || $material_name ne ""} {
        set id [$node getAttribute n]
        set found 0
        set val 0.0
        
        # primero miramos si el material tiene ese campo
        if {$material_name ne ""} {
            set nodeApp [GetAppIdFromNode $node]
            set mats_un [apps::getAppUniqueName $nodeApp Materials]
            set xp3 [spdAux::getRoute $mats_un]
            append xp3 [format_xpath {/blockdata[@n="material" and @name=%s]/value} $material_name]
            foreach valueNode [$root selectNodes $xp3] {
                if {$id eq [$valueNode getAttribute n] } {set val [$valueNode getAttribute v]; set found 1; break}
            }
            #if {$found} {W "mat $material_name value $val"}
        }
        # si no está en el material, miramos en el elemento
        if {!$found} {
            set element_name [get_domnode_attribute [[$node parent] selectNodes "./value\[@n='Element'\]"] v]
            #set claw_name [.gid.central.boundaryconds.gg.data.f0.e1 get]
            set element [Model::getElement $element_name]
            if {$element ne ""} {
                set val [$element getInputDv $id]
                if {$val ne ""} {set found 1}
            }
            #if {$found} {W "element $element_name value $val"}
        }
        # Si no está en el elemento, miramos en la ley constitutiva
        if {!$found} {
            set claw_name [get_domnode_attribute [[$node parent] selectNodes "./value\[@n='ConstitutiveLaw'\]"] v]
            set claw [Model::getConstitutiveLaw $claw_name]
            if {$claw ne ""} {
                set val [$claw getInputDv $id]
                if {$val ne ""} {set found 1}
            }
            #if {$found} {W "claw $claw_name value $val"}
        }
        #if {!$found} {W "Not found $val"}
        if {$val eq ""} {set val 0.0} {return $val}
    }
}

proc spdAux::ProcPartParamValue { domNode args } {
    #W [$domNode asXML]
    return [spdAux::CheckPartParamValue $domNode ""]
    if {[$domNode name] eq "value"} {
        set node [$domNode selectNode "../value\[@n='Material'\]" ]
        #W $node
        set matname [get_domnode_attribute $node v]
        #W $matname
        return [spdAux::CheckPartParamValue $domNode $matname]
    } 
}
proc spdAux::ProcPartParamState { domNode args } {
    #W [get_domnode_attribute $domNode v]
    #W [$domNode @v]
    set resp [::Model::CheckElemParamState $domNode]
    if {$resp eq "0"} {
        set id [$domNode getAttribute n]
        set constLaw [get_domnode_attribute [[$domNode parent] selectNodes "./value\[@n='ConstitutiveLaw'\]"] v]
        if {$constLaw eq ""} {return hidden}
        set resp [Model::CheckConstLawParamState $constLaw $id]
    }
    
    #W "Calculando estado de [$domNode @pn] : $resp"
    if {$resp} {return "normal"} else {return "hidden"}
}
proc spdAux::ProcSolverEntryState { domNode args } {
    
    set resp [spdAux::CheckSolverEntryState $domNode]
    if {$resp} {return "normal"} else {return "hidden"}
}
proc spdAux::ProcCheckDimension { domNode args } {
    
    set checkdim [lindex $args 0]
    
    if {$checkdim eq $::Model::SpatialDimension} {return "normal"} else {return "hidden"}
}
proc spdAux::ProcgetStateFromXPathValue2 { domNode args } {
    set args {*}$args
    set arglist [split $args " "]
    set xpath {*}[lindex $arglist 0]
    set checkvalue [lindex $arglist 1]
    set pst [$domNode selectNodes $xpath]
    #W "xpath $xpath checkvalue $checkvalue pst $pst"
    if {$pst == $checkvalue} { return "normal"} else {return "hidden"}
}

proc spdAux::ProcgetStateFromXPathValue { domNode args } {
    set args {*}$args
    set arglist [split $args " "]
    set xpath {*}[lindex $arglist 0]
    set checkvalue [split [lindex $arglist 1] ","]
    set pst [$domNode selectNodes $xpath]
    #W "xpath $xpath checkvalue $checkvalue pst $pst"
    if {$pst in $checkvalue} { return "normal"} else {return "hidden"}
}
proc spdAux::ProcSolStratParamState { domNode args } {
    
    set resp [::spdAux::SolStratParamState $domNode]
    if {$resp} {return "normal"} else {return "hidden"}
}
proc spdAux::ProcSchemeParamState { domNode args } {
    
    set resp [::spdAux::SchemeParamState $domNode]
    if {$resp} {return "normal"} else {return "hidden"}
}  
proc spdAux::ProcConstLawOutputState { domNode args } {
    
    set resp [::spdAux::CheckConstLawOutputState $domNode]
    if {$resp} {return "normal"} else {return "hidden"}
}
proc spdAux::ProcElementOutputState { domNode args } {
    
    set resp [::spdAux::CheckElementOutputState $domNode]
    if {$resp} {return "normal"} else {return "hidden"}
}

proc spdAux::ProcActiveIfAnyPartState { domNode args } {
    
    set parts ""
    set nodeApp [GetAppIdFromNode $domNode]
    set parts_un [apps::getAppUniqueName $nodeApp Parts]
    set parts_path [spdAux::getRoute $parts_un]
    if {$parts_path ne ""} {
        set parts [$domNode selectNodes "$parts_path/group"]
    }
    if {$parts ne ""} {return "normal"} else {return "hidden"}
}
proc spdAux::ProcActiveIfRestartAvailable { domNode args } {
    
    set active [apps::ExecuteOnApp [GetAppIdFromNode $domNode] GetAttribute UseRestart]
    if {$active ne "" && $active} {return "normal"} else {return "hidden"}
}

proc spdAux::ProcDisableIfUniqueName { domNode args } {
    return [ProcChangeStateIfUniqueName $domNode disabled {*}$args]
}
proc spdAux::ProcHideIfUniqueName { domNode args } {
    return [ProcChangeStateIfUniqueName $domNode hidden {*}$args]
}
proc spdAux::ProcChangeStateIfUniqueName { domNode newState args } {
    set total 1
    foreach {un val} {*}$args {
        set xpath [spdAux::getRoute $un]
        spdAux::insertDependencies $domNode $un
        set node [$domNode selectNodes $xpath]
        if {$node eq ""} {
            set total 0
            W "Warning: state of [$domNode @n]"
        } else {
            set realval [get_domnode_attribute $node v]
            if {$realval eq ""} {W "Warning: Check unique name $un"}
            if {[lsearch $val $realval] == -1} {
                set total 0
                break
            } 
        }
    }
    if {!$total} {return "normal"} else {return $newState}
}
proc spdAux::ProcCheckGeometry { domNode args } {
    
    set level [lindex $args 0]
    #W $level
    if {$level eq 1} {
        if {$::Model::SpatialDimension eq "3D"} {return volume} {return surface}
    }
    if {$level eq 2} {
        if {$::Model::SpatialDimension eq "3D"} {return surface} {return line}
    }
}
proc spdAux::ProcDirectorVectorNonZero { domNode args } {
    
    set kw [lindex $args 0]
    set update 0
    foreach condgroupnode [$domNode getElementsByTagName group] {
        set valid 0
        foreach dirnode [$condgroupnode getElementsByTagName value] {
            if {[string first $kw [get_domnode_attribute $dirnode n]] eq 0 } {
                if { [get_domnode_attribute $dirnode v] != 0 } {set valid 1; break}
            }
        }
        if {!$valid} {
            $domNode removeChild $condgroupnode
            set update 1
        }
    }
    if {$update} {
        W "Director vector can't be null"
        gid_groups_conds::actualize_conditions_window
    }
}
proc spdAux::ProcShowInMode { domNode args } {
    set kw [lindex $args 0]
    if {$kw ni [list "Release" "Developer"]} {return "hidden"}
    if {$::Kratos::kratos_private(DevMode) eq "dev"} {
        if {$kw eq "Developer"} {return "normal"} {return "hidden"}
    }
    if {$::Kratos::kratos_private(DevMode) eq "release"} {
        if {$kw eq "Developer"} {return "hidden"} {return "normal"}
    }
}


proc spdAux::LoadModelFiles { } {
    customlib::UpdateDocument
    foreach elem [[customlib::GetBaseRoot] getElementsByTagName "file"] {
        FileSelector::AddFile [$elem @n]
    }
}
proc spdAux::SaveModelFile { fileid } {
    customlib::UpdateDocument
    FileSelector::AddFile $fileid
    gid_groups_conds::addF {container[@n='files']} file [list n ${fileid}]
}

proc spdAux::AddFile { domNode } {
    FileSelector::InitWindow "spdAux::UpdateFileField" $domNode
}
proc spdAux::UpdateFileField { fileid domNode} {
    if {$fileid ne ""} {
        $domNode setAttribute v $fileid
        spdAux::SaveModelFile $fileid
        RequestRefresh 
    }
}
proc spdAux::ProcGetFilesValues { } {
    lappend listilla "- No file"
    lappend listilla {*}[FileSelector::GetAllFiles]
    lappend listilla "- Add new file"
    return [join $listilla ","]
}

proc spdAux::ProcGetIntervals {domNode args} {
    set lista [::spdAux::getIntervals]
    if {$lista eq ""} {$domNode setAttribute state "hidden"; spdAux::RequestRefresh}
    if {[$domNode @v] eq "" || [$domNode @v] ni $lista} {
        $domNode setAttribute v [lindex $lista 0]
    }
    set res [spdAux::ListToValues $lista]
    return $res
}

proc spdAux::PreChargeTree { } {
    return ""
    
    set root [customlib::GetBaseRoot]
    
    foreach field [list value condition container] {
        foreach cndNode [$root getElementsByTagName $field] {
            set a [get_domnode_attribute $cndNode dict]
            set a [get_domnode_attribute $cndNode values]
            set a [get_domnode_attribute $cndNode v]
            #W [get_domnode_attribute $cndNode n]
        }
    }
}

proc spdAux::ProcGive_materials_list {domNode args} {
    set optional {
        { -has_container container_name "" }
        { -icon icon_name material16 }
        { -types_icon types_icon_name ""}
        { -database database_name materials }
    }        
    #W $args
    set compulsory ""
    parse_args $optional $compulsory $args      
    set restList ""    
    
    proc database_append_list { parentNode database_name level container_name icon_name types_icon_name } {
        set l ""       
        # We guess the keywords of the levels of the database        
        set level_names [give_levels_name $parentNode $database_name]
        set primary_level [lindex $level_names 0]
        set secondary_level [lindex $level_names 1]
        
        if {$secondary_level eq "" && $container_name ne "" && $level == "0"} {
            error [_ "The has_container flag is not available for the database %s (the different types of materials \
                    should be distributed in several containers)" $database_name]     
        }
        
        foreach domNode [$parentNode childNodes] {
            set name [$domNode @pn ""]
            if { $name eq "" } { set name [$domNode @name] }
            if { [$domNode @n] eq "$secondary_level" } {
                set ret [database_append_list $domNode  $database_name \
                        [expr {$level+1}] $container_name $icon_name $types_icon_name]
                if { [llength $ret] } {
                    lappend l [list $level $name $name $types_icon_name 0]
                    eval lappend l $ret
                }
            } elseif {[$domNode @n] eq "$primary_level"} {
                set good 1
                if { $container_name ne "" } {
                    set xp [format_xpath {container[@n=%s]} $container_name]
                    if { [$domNode selectNodes $xp] eq "" } { set good 0 }
                }
                if { $good } {
                    lappend l [list $level $name $name $icon_name 1]
                }
            }
        }
        return $l
    }  
    
    proc give_caption_name { domNode xp database_name } {     
        set first_time 1
        foreach gNode [$domNode selectNodes $xp] {        
            if {$first_time} {
                set caption_name [$gNode @n]
                set first_time 0 
                continue  
            }
            if {[$gNode @n] ne $caption_name} {
                error [_ "Please check the n attributes of the database %s" $database_name]   
            }     
        }  
        return $caption_name   
    }
    
    proc give_levels_name { domNode name } {
        set xp {container}      
        if {[$domNode selectNodes $xp] eq ""} { 
            # No seconday level exists
            set secondary_level ""
            set xp2 {blockdata}  
            set primary_level [give_caption_name $domNode $xp2 $name]
        } else {
            set secondary_level [give_caption_name $domNode $xp $name]
            set xp3 {container/blockdata}
            set primary_level [give_caption_name $domNode $xp3 $name] 
        }
        return [list $primary_level $secondary_level]
    } 
    #W $database
    set appid [spdAux::GetAppIdFromNode $domNode]
    set mats_un [apps::getAppUniqueName $appid Materials]
    set xp3 [spdAux::getRoute $mats_un]
    set parentNode [$domNode selectNodes $xp3]
    #W [$parentNode asXML]
    if {$parentNode eq ""} {
        error [_ "Database %s not found in the spd file" $database]  
    }
    
    eval lappend resList [database_append_list $parentNode \
            $database 0 $has_container $icon $types_icon]
    return [join $resList ","]
}

proc spdAux::ProcEdit_database_list {domNode args} {
    set root [customlib::GetBaseRoot]
    set matname ""
    set xnode "[$domNode @n]:"
    set baseframe ".gid.central.boundaryconds.gg.data.f0"
    set things [winfo children $baseframe]
    foreach thing $things {
        if {[winfo class $thing] eq "TLabel"} {
            set lab [$thing cget -text]
            if {$lab eq $xnode} {
                set id [string range [lindex [split $thing "."] end] 1 end]
                set cbo ${baseframe}.e$id
                set matname [$cbo get]
                break
            }
        }
    }
    if {$matname ne ""} {
        foreach thing $things {
            set found 0
            #set id ""
            if {[winfo class $thing] eq "TPanedwindow"} {
                #set id [string range [lindex [split $thing "."] end] 1 end]
                set thing "${thing}.e"
            }
            if {[winfo class $thing] eq "TEntry"} {
                #if {$id eq "" } {set id [string range [lindex [split $thing "."] end] 1 end]}
                #set prop ${baseframe}.e$id
                set varname [$thing cget -textvariable]
                set propname [lindex [split [lindex [split [lindex [split $varname "::"] end] "("] end] ")"] 0]
                #W $propname
                set appid [spdAux::GetAppIdFromNode $domNode]
                set mats_un [apps::getAppUniqueName $appid Materials]
                set xp3 [spdAux::getRoute $mats_un]
                append xp3 [format_xpath {/blockdata[@n="material" and @name=%s]/value} $matname]
                
                foreach valueNode [$root selectNodes $xp3] {
                    if {$propname eq [$valueNode getAttribute n] } {
                        set val [$valueNode getAttribute v]
                        set $varname $val
                        #set found 1
                        break
                    }
                }
                #if {$found} {W "mat $matname value $val"}
                
            }
        }
    }
    return ""
}

proc spdAux::ProcCambioMat {domNode args} {
    set matname [get_domnode_attribute $domNode v]
    set exclusion [list "Element" "ConstitutiveLaw" "Material"]
    set nodes [$domNode selectNodes "../value"]
    foreach node $nodes {
        if {[$node @n] ni $exclusion} {
            #W "[$node @n] [CheckPartParamValue $node $matname]"
            $node setAttribute v [CheckPartParamValue $node $matname]
        }
    }
    RequestRefresh
}
proc spdAux::ProcOkNewCondition {domNode args} {
    set cnd_id [$domNode @n]
    set condition [Model::getCondition $cnd_id]
    
    set group_node [$domNode lastChild]
    set interval [$group_node selectNodes "./value\[@n='Interval'\]"]
    if {$interval ne ""} {
        set group_id [$group_node @n]
        set interval_id [get_domnode_attribute $interval v]
        set new_group_id "$group_id//$interval_id"
        set i 0
        while {[GiD_Groups exists $new_group_id]} {
            set new_group_id "$group_id//$interval_id - $i"
            incr i
        }
        GiD_Groups create $new_group_id
        foreach ent [list points lines surfaces volumes nodes elements] {
            GiD_EntitiesGroups assign $new_group_id $ent [GiD_EntitiesGroups get $group_id $ent]
        }
        #GiD_Groups edit state $new_group_id hidden
        $group_node setAttribute n $new_group_id
        AddIntervalGroup $group_id $new_group_id
        
        GiD_Groups window update
        RequestRefresh
    }
}

proc spdAux::ProcConditionParameterState {domNode args} {
    set param_name [get_domnode_attribute $domNode n]
    set cond_node [$domNode parent]
    if {[$cond_node nodeName] eq "group"} {set cond_node [$cond_node parent]}
    set cond_name [get_domnode_attribute $cond_node n]

    set cond [Model::getCondition $cond_name]
    if {$cond eq ""} {
        set cond [Model::getNodalConditionbyId $cond_name]
        if {$cond eq ""} {
            W "No condition found with name $cond_name" ; return normal
        }
    }
    set process_name [$cond getProcessName]
    set process [Model::GetProcess $process_name]
    set param [$process getInputPn $param_name]
    if {$param eq ""} {return normal}

    set depN [$param getDepN]
    if {$depN ne ""} {
        set depV [$param getDepV]
        set realV [get_domnode_attribute [$domNode selectNodes "../value\[@n='$depN'\]"] v]
        if {$depV ne $realV} {return hidden}
    }

    return normal
}

proc spdAux::LoadIntervalGroups { } {
    customlib::UpdateDocument
    variable GroupsEdited
    
    foreach elem [[customlib::GetBaseRoot] getElementsByTagName "interval_group"] {
        dict lappend GroupsEdited [$elem @parent] [$elem @child]
    }
}
proc spdAux::AddIntervalGroup { parent child } {
    variable GroupsEdited
    dict lappend GroupsEdited $parent $child
    customlib::UpdateDocument
    gid_groups_conds::addF {container[@n='interval_groups']} interval_group [list parent ${parent} child ${child}]
}


proc spdAux::AddConditionGroupOnXPath {xpath groupid} {
    
    set root [customlib::GetBaseRoot]
    set node [$root selectNodes $xpath]
    return [AddConditionGroupOnNode $node $groupid]
}
proc spdAux::AddConditionGroupOnNode {basenode groupid} {
    set prev [$basenode selectNodes "./group\[@n='$groupid'\]"]
    if {$prev ne ""} {return $prev}
    set newNode [gid_groups_conds::addF [$basenode toXPath] group [list n $groupid]]
    foreach val [$basenode childNodes] {
        if {[$val nodeName] eq "value"} {
            set newChild [$val cloneNode -deep]
            $newNode appendChild $newChild
        }
    }
    return $newNode
}
proc spdAux::ProcGetParts {domNode args} {
    set parts ""
    set nodeApp [GetAppIdFromNode $domNode]
    set parts_un [apps::getAppUniqueName $nodeApp Parts]
    set parts_path [spdAux::getRoute $parts_un]
    if {$parts_path ne ""} {
        foreach part [$domNode selectNodes "$parts_path/group"] {
            lappend parts [$part @n]
        }
    }
    if {[llength $parts]} { if {[$domNode @v] ni $parts} {$domNode setAttribute v [lindex $parts 0]}}
    return [join $parts ","]
}

proc spdAux::ProcUpdateParts {domNode args} {
    # Algo comun?
    # W "Common"

    # Active app executexml
    set nodeApp [GetAppIdFromNode $domNode]
    apps::ExecuteOnAppXML $nodeApp UpdateParts $domNode
}