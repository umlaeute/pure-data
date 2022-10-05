## infrastructure for drawing Pd "widgets" (graphical objects)
package provide pdwidget_iemgui 0.1

namespace eval ::pd::widget::iemgui:: { }


proc ::pd::widget::iemgui::create_bang {obj cnv posX posY} {
    set tag [::pd::widget::base_tag $obj]
    $cnv create rectangle 0 0 0 0 -tags [list ${tag}] -outline {} -fill {} -width 0
    $cnv create rectangle 0 0 0 0 -tags [list ${tag} BASE]
    $cnv create oval 0 0 0 0 -tags [list ${tag} BUTTON]
    $cnv create rectangle 0 0 0 0 -tags [list ${tag} iolets] -outline {} -fill {}
    $cnv create text 0 0 -anchor w -tags [list ${tag} label text]
    $cnv move $tag $posX $posY

    ::pd::widget::widgetbehavior $obj config ::pd::widget::iemgui::config_bang
    ::pd::widget::widgetbehavior $obj select ::pd::widget::iemgui::select
}


########################################################################
# common procedures

proc ::pd::widget::iemgui::select {obj state} {
    # if selection is activated, use a different color
    # TODO: label

    if {$state != 0} {
        set color #0000FF
    } else {
        set color #000000
    }
    set tag "[::pd::widget::base_tag $obj]"
    foreach cnv [::pd::widget::get_canvases $obj] {
        $cnv itemconfigure "${tag}&&BASE" -outline $color
        $cnv itemconfigure "${tag}&&BUTTON" -outline $color
    }
}

# this is a helper to be called from the object-specific 'config' procs
# that deals with the labels (it's the same with every iemgui)
proc ::pd::widget::iemgui::_config_common {tag cnv options} {
    set zoom [::pd::canvas::get_zoom $cnv]
    foreach {xpos ypos _ _} [$cnv coords "${tag}"] {break}
    dict for {k v} $options {
        switch -exact -- $k {
            default {
            } "-labelpos" {
                set xnew [lindex $v 0]
                set ynew [lindex $v 1]
                $cnv coords "${tag}&&label" \
                    [expr $xpos + $xnew * $zoom] [expr $ypos + $ynew * $zoom]
            } "-label" {
                pdtk_text_set $cnv "${tag}&&label" $v
            } "-font" {
                set fontweight $::font_weight
                set font [lindex $v 0]
                set fontsize [lindex $v 1]
                set fontsize [expr -int($fontsize) * $zoom]
                $cnv itemconfigure "${tag}&&label" -font [list $font $fontsize $fontweight]
            }
        }
    }
}

########################################################################
# [bng]
proc ::pd::widget::iemgui::config_bang {obj args} {
    set options [::pd::widget::parseargs \
                     {
                         -labelpos 2
                         -size 2
                         -colors 3
                         -font 2
                         -label 1
                     } $args]
    set tag [::pd::widget::base_tag $obj]
    set recreate_iolets 0

    foreach cnv [::pd::widget::get_canvases $obj] {
        set zoom [::pd::canvas::get_zoom $cnv]
        set iow $::pd::widget::IOWIDTH
        set ih [expr $::pd::widget::IHEIGHT - 0.5]
        set oh [expr $::pd::widget::OHEIGHT - 1]
        ::pd::widget::iemgui::_config_common $tag $cnv $options
        foreach {xpos ypos _ _} [$cnv coords "${tag}"] {break}
        dict for {k v} $options {
            switch -exact -- $k {
                default {
                } "-size" {
                    foreach {xpos ypos _ _} [$cnv coords "${tag}"] {break}
                    set xnew [lindex $v 0]
                    set ynew [lindex $v 1]
                    $cnv coords "${tag}" \
                        $xpos                        $ypos                  \
                        [expr $xpos + $xnew * $zoom] [expr $ypos + $ynew * $zoom]
                    $cnv coords "${tag}&&BASE" \
                        $xpos                        $ypos                  \
                        [expr $xpos + $xnew * $zoom] [expr $ypos + $ynew * $zoom]
                    $cnv coords "${tag}&&BUTTON" \
                        [expr $xpos +                 $zoom] [expr $ypos +                 $zoom] \
                        [expr $xpos + ($xnew - 1.5) * $zoom] [expr $ypos + ($ynew - 1.5) * $zoom]
                    set recreate_iolets 1
                } "-colors" {
                    set color [lindex $v 0]
                    $cnv itemconfigure "${tag}&&BASE" -fill $color
                    if { [$cnv itemcget "${tag}&&BUTTON" -fill] ne {} } {
                        set color [lindex $v 1]
                        $cnv itemconfigure "${tag}&&BUTTON" -fill $color
                    }
                    set color [lindex $v 2]
                    $cnv itemconfigure "${tag}&&label" -fill $color
                }

            }
            $cnv itemconfigure "${tag}&&BASE" -width $zoom
            $cnv itemconfigure "${tag}&&BUTTON" -width $zoom
        }
    }
    if {$recreate_iolets} {
        ::pd::widget::refresh_iolets $obj
    }
}

########################################################################
# [cnv]
proc ::pd::widget::iemgui::create_canvas {obj cnv posX posY} {
    set tag [::pd::widget::base_tag $obj]
    $cnv create rectangle 0 0 0 0 -tags [list ${tag}] -outline {} -fill {} -width 0
    $cnv create rectangle 0 0 0 0 -tags [list ${tag} RECT]
    $cnv create rectangle 0 0 0 0 -tags [list ${tag} BASE]
    $cnv create text 0 0 -anchor w -tags [list ${tag} label text]
    $cnv move $tag $posX $posY

    ::pd::widget::widgetbehavior $obj config ::pd::widget::iemgui::config_canvas
    ::pd::widget::widgetbehavior $obj select ::pd::widget::iemgui::select_canvas
}
proc ::pd::widget::iemgui::config_canvas {obj args} {
    set options [::pd::widget::parseargs \
                     {
                         -labelpos 2
                         -size 2
                         -visible 2
                         -colors 3
                         -font 2
                         -label 1
                     } $args]
    set tag [::pd::widget::base_tag $obj]

    foreach cnv [::pd::widget::get_canvases $obj] {
        set zoom [::pd::canvas::get_zoom $cnv]
        set offset 0
        if {$zoom > 1} {
            set offset $zoom
        }

        ::pd::widget::iemgui::_config_common $tag $cnv $options
        dict for {k v} $options {
            foreach {xpos ypos _ _} [$cnv coords "${tag}"] {break}
            switch -exact -- $k {
                default {
                } "-size" {
                    set xnew [lindex $v 0]
                    set ynew [lindex $v 1]
                    $cnv coords "${tag}&&BASE" \
                        [expr $xpos + $offset]                 [expr $ypos + $offset] \
                        [expr $xpos + $offset + $xnew * $zoom] [expr $ypos + $offset + $ynew * $zoom]
                } "-visible" {
                    set w [lindex $v 0]
                    set h [lindex $v 1]
                    $cnv coords "${tag}"       $xpos $ypos [expr $xpos + $w * $zoom] [expr $ypos + $h * $zoom]
                    $cnv coords "${tag}&&RECT" $xpos $ypos [expr $xpos + $w * $zoom] [expr $ypos + $h * $zoom]
                } "-colors" {
                    set color [lindex $v 0]
                    $cnv itemconfigure "${tag}&&RECT" -fill $color -outline $color
                    $cnv itemconfigure "${tag}&&BASE" -width 1 -outline {}
                    # set unused_color [lindex $v 1]
                    set color [lindex $v 2]
                    $cnv itemconfigure "${tag}&&label" -fill $color
                }
            }
        }
        $cnv itemconfigure "${tag}&&BASE" -width $zoom
        # TODO: in the original code, BASE was shifted by $offset to 'keep zoomed border inside visible area'
    }
}
proc ::pd::widget::iemgui::select_canvas {obj state} {
    # get the normal color from the object's state
    # if selection is activated, use a different color
    if {$state != 0} {
        set color #0000FF
    } else {
        set color {}
    }
    set tag "[::pd::widget::base_tag $obj]&&BASE"
    foreach cnv [::pd::widget::get_canvases $obj] {
        $cnv itemconfigure ${tag} -outline $color
    }
}

########################################################################
# [hradio], [vradio]
proc ::pd::widget::iemgui::create_radio {obj cnv posX posY} {
    set tag [::pd::widget::base_tag $obj]
    $cnv create rectangle 0 0 0 0 -tags [list ${tag}] -outline {} -fill {} -width 0
    $cnv create rectangle 0 0 0 0 -tags [list ${tag} BASE0]
    $cnv create rectangle 0 0 0 0 -tags [list ${tag} iolets] -outline {} -fill {}
    $cnv create text 0 0 -anchor w -tags [list ${tag} label text]
    $cnv move $tag $posX $posY

    ::pd::widget::widgetbehavior $obj config ::pd::widget::iemgui::config_radio
    ::pd::widget::widgetbehavior $obj select ::pd::widget::iemgui::select
}
proc ::pd::widget::iemgui::_radio_recreate_buttons {cnv obj numX numY} {
    # create an array of numX*numY buttons
    set tag [::pd::widget::base_tag $obj]
    $cnv delete ${tag}&&RADIO
    for {set x 0} {$x < $numX} {incr x} {
        for {set y 0} {$y < $numY} {incr y} {
            $cnv create rectangle 0 0 0 0 -fill {} -outline {} \
                -tags [list ${tag} RADIO BASE GRID${x}x${y}]
            $cnv create rectangle 0 0 0 0 -fill {} -outline {} \
                -tags [list ${tag} RADIO KNOB GRID${x}x${y}]
        }
    }
    $cnv lower "${tag}&&RADIO" "${tag}&&BASE0"
    $cnv raise "${tag}&&RADIO" "${tag}&&BASE0"
}
proc ::pd::widget::iemgui::_radio_getactive {cnv tag} {
    set t {}
    foreach t [$cnv find withtag ${tag}&&X] {break}
    if { $t eq {} } {return}
    # we have an active button, but which one is it?
    set i 0
    foreach t [$cnv find withtag ${tag}&&KNOB] {
        if {[lsearch -exact [$cnv gettags $t] X] >= 0} {
            # found it
            return [list $i [$cnv itemcget $t -fill]]
        }
        incr i
    }
}
proc ::pd::widget::iemgui::_radio_reconfigure_buttons {cnv obj zoom} {
    set tag [::pd::widget::base_tag $obj]
    foreach {xpos ypos w h} [$cnv coords "${tag}&&BASE0"] {break}
    set w [expr $w - $xpos]
    set h [expr $h - $ypos]

    set knob_x0 [expr $w / 4 - 0.5]
    set knob_y0 [expr $h / 4 - 0.5]
    set knob_x1 [expr $w - $knob_x0]
    set knob_y1 [expr $h - $knob_y0]

    # get the coord of the outlet...
    set ylast $ypos
    set numX 0
    set numY 0

    # resize/reposition the buttons
    foreach id [$cnv find withtag "${tag}&&KNOB"] {
        set x {}
        set y {}
        foreach t [$cnv gettags $id] {
            if { [regexp {^GRID(.+)x(.+)} $t _ x y] } {
                break;
            }
        }
        if { $x eq {} || $y eq {} } { break }
        if {$x > $numX} {set numX $x}
        if {$y > $numY} {set numY $y}

        set xy "${x}x${y}"
        set ylast [expr $h * $y]
        $cnv coords "${tag}&&BASE&&GRID${xy}" 0 0 $w $h
        $cnv coords "${tag}&&KNOB&&GRID${xy}" $knob_x0 $knob_y0 $knob_x1 $knob_y1
        $cnv move "${tag}&&GRID${xy}" [expr $w * $x] $ylast
    }
    $cnv itemconfigure "${tag}&&BASE" -outline black
    $cnv move "${tag}&&RADIO" $xpos $ypos

    $cnv coords "${tag}" $xpos $ypos [expr $xpos + ($numX + 1) * $w * $zoom] [expr $ypos + ($numY + 1) * $h * $zoom]

}
proc ::pd::widget::iemgui::config_radio {obj args} {
    set options [::pd::widget::parseargs \
                     {
                         -labelpos 2
                         -size 2
                         -colors 3
                         -font 2
                         -label 1
                         -number 2
                     } $args]
    set tag [::pd::widget::base_tag $obj]
    set canvases [::pd::widget::get_canvases $obj]
    set recreate_iolets 0

    # which button is activated?
    set active {}
    set activecolor {}
    set bgcolor {}
    foreach cnv $canvases {
        foreach {active activecolor} [::pd::widget::iemgui::_radio_getactive $cnv $tag] {break}
        set bgcolor [$cnv itemcget "${tag}&&BASE" -fill]
        # we only check a single canvas (they are all the same)
        break;
    }
    foreach cnv $canvases {
        set zoom [::pd::canvas::get_zoom $cnv]
        ::pd::widget::iemgui::_config_common $tag $cnv $options
        dict for {k v} $options {
            switch -exact -- $k {
                default {
                } "-colors" {
                    set bgcolor [lindex $v 0]
                    set activecolor [lindex $v 1]
                    set labelcolor [lindex $v 2]
                    $cnv itemconfigure "${tag}&&label" -fill $labelcolor
                } "-size" {
                    set w [lindex $v 0]
                    set h [lindex $v 1]
                    foreach {x y} [$cnv coords "${tag}&&BASE0"] {break}
                    $cnv coords "${tag}&&BASE0" $x $y [expr $x + $w * $zoom] [expr $y + $h * $zoom]
                    ::pd::widget::iemgui::_radio_reconfigure_buttons $cnv $obj $zoom
                    set recreate_iolets 1
                } "-number" {
                    set xnew [lindex $v 0]
                    set ynew [lindex $v 1]
                    ::pd::widget::iemgui::_radio_recreate_buttons $cnv $obj $xnew $ynew
                    ::pd::widget::iemgui::_radio_reconfigure_buttons $cnv $obj $zoom
                    set recreate_iolets 1
                }

            }
        }
        $cnv itemconfigure "${tag}&&BASE" -width $zoom -fill $bgcolor
    }
    if { $active ne {} } {
        ::pd::widget::radio::activate $obj $active $activecolor
    }
    if { $recreate_iolets } {
        set iolets [::pd::widget::get_iolets $obj inlet]
        ::pd::widget::create_inlets $obj {*}$iolets
        set iolets [::pd::widget::get_iolets $obj outlet]
        ::pd::widget::create_outlets $obj {*}$iolets
    }
}

########################################################################
# [tgl]
proc ::pd::widget::iemgui::create_toggle {obj cnv posX posY} {
    set tag [::pd::widget::base_tag $obj]
    $cnv create rectangle 0 0 0 0 -tags [list ${tag}] -outline {} -fill {} -width 0
    $cnv create rectangle 0 0 0 0 -tags [list ${tag} BASE]
    $cnv create line 0 0 0 0 -tags [list ${tag} X X1] -fill {}
    $cnv create line 0 0 0 0 -tags [list ${tag} X X2] -fill {}
    $cnv create rectangle 0 0 0 0 -tags [list ${tag} iolets] -outline {} -fill {}
    $cnv create text 0 0 -anchor w -tags [list ${tag} label text]
    $cnv move $tag $posX $posY

    ::pd::widget::widgetbehavior $obj config ::pd::widget::iemgui::config_toggle
    ::pd::widget::widgetbehavior $obj select ::pd::widget::iemgui::select
}
proc ::pd::widget::iemgui::config_toggle {obj args} {
    set options [::pd::widget::parseargs \
                     {
                         -labelpos 2
                         -size 2
                         -colors 3
                         -font 2
                         -label 1
                     } $args]
    set tag [::pd::widget::base_tag $obj]
    set recreate_iolets 0

    foreach cnv [::pd::widget::get_canvases $obj] {
        set zoom [::pd::canvas::get_zoom $cnv]
        set iow $::pd::widget::IOWIDTH
        set ih [expr $::pd::widget::IHEIGHT - 0.5]
        set oh [expr $::pd::widget::OHEIGHT - 1]
        ::pd::widget::iemgui::_config_common $tag $cnv $options
        foreach {xpos ypos _ _} [$cnv coords "${tag}"] {break}
        dict for {k v} $options {
            switch -exact -- $k {
                default {
                } "-size" {
                    set xnew [lindex $v 0]
                    set ynew [lindex $v 1]
                    $cnv coords "${tag}" \
                        $xpos                        $ypos                  \
                        [expr $xpos + $xnew * $zoom] [expr $ypos + $ynew * $zoom]
                    $cnv coords "${tag}&&BASE" \
                        $xpos                        $ypos                  \
                        [expr $xpos + $xnew * $zoom] [expr $ypos + $ynew * $zoom]

                    set crossw [expr abs(int($xnew/30)) + 2]
                    set x0 [expr $xpos +          $crossw  * $zoom]
                    set y0 [expr $ypos +          $crossw  * $zoom]
                    set x1 [expr $xpos + ($xnew - $crossw) * $zoom]
                    set y1 [expr $ypos + ($ynew - $crossw) * $zoom]
                    $cnv coords "${tag}&&X1" $x0 $y0 $x1 $y1
                    $cnv coords "${tag}&&X2" $x0 $y1 $x1 $y0
                    $cnv itemconfigure ${tag}&&X -width [expr $crossw - 1]
                    set recreate_iolets 1
                } "-colors" {
                    set color [lindex $v 0]
                    $cnv itemconfigure "${tag}&&BASE" -fill $color
                    if { [$cnv itemcget "${tag}&&X" -fill] ne {} } {
                        set color [lindex $v 1]
                        $cnv itemconfigure "${tag}&&X" -fill $color
                    }
                    set color [lindex $v 2]
                    $cnv itemconfigure "${tag}&&label" -fill $color
                }

            }
            $cnv itemconfigure "${tag}&&BASE" -width $zoom
        }
    }
    if {$recreate_iolets} {
        ::pd::widget::refresh_iolets $obj
    }
}

########################################################################
# object-specific procs from the core
#
# for whatever reasons, we use per-object namespaces
namespace eval ::pd::widget::radio:: { }
proc ::pd::widget::radio::activate {obj state activecolor} {
    set tag "[::pd::widget::base_tag $obj]"
    foreach cnv [::pd::widget::get_canvases $obj] {
        # pass the 'activated' tag to the newly selected button
        $cnv dtag "${tag}" "X"
        set id [lindex [$cnv find withtag ${tag}&&KNOB] $state]
        if { $id ne {} } {
            $cnv addtag "X" withtag $id
        }
        # show (de)activation
        $cnv itemconfigure "${tag}&&KNOB" -fill {} -outline {}
        $cnv itemconfigure "${tag}&&X" -fill $activecolor -outline $activecolor
    }
}

namespace eval ::pd::widget::bang:: { }
proc ::pd::widget::bang::activate {obj state activecolor} {
    # LATER: have the timer work on the GUI side!
    set tag "[::pd::widget::base_tag $obj]&&BUTTON"
    if {! $state} {
        set activecolor {}
    }
    foreach cnv [::pd::widget::get_canvases $obj] {
        $cnv itemconfigure $tag -fill $activecolor
    }
}

namespace eval ::pd::widget::toggle:: { }
proc ::pd::widget::toggle::activate {obj state activecolor} {
    set tag "[::pd::widget::base_tag $obj]"
    set tag "${tag}&&X"
    if {! $state} {
        set activecolor {}
    }
    foreach cnv [::pd::widget::get_canvases $obj] {
        $cnv itemconfigure $tag -fill $activecolor
    }
}



########################################################################
# register the new objects
::pd::widget::register bang ::pd::widget::iemgui::create_bang
::pd::widget::register canvas ::pd::widget::iemgui::create_canvas
::pd::widget::register radio ::pd::widget::iemgui::create_radio
::pd::widget::register toggle ::pd::widget::iemgui::create_toggle
