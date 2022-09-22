## infrastructure for drawing Pd "widgets" (graphical objects)
package provide pdwidget_bang 0.1


namespace eval ::pd::widget::bang:: {

}

proc printme {args} {
    ::pdwindow::error "${args}\n"
}
proc debug {args} {
    ::pdwindow::error "${args}\n"
    {*}$args
}
proc ::pd::widget::bang::create {obj cnv} {
    set tag [::pd::widget::base_tag $obj]
    $cnv create rectangle 0 0 0 0 -tags [list ${tag}] -outline {} -fill {} -width 0
    $cnv create rectangle 0 0 0 0 -tags [list ${tag} ${tag}BASE]
    $cnv create oval 0 0 0 0 -tags [list ${tag} ${tag}BUT]
    $cnv create rectangle 0 0 0 0 -tags [list ${tag} ${tag}INLET] -outline {} -fill {}
    $cnv create rectangle 0 0 0 0 -tags [list ${tag} ${tag}OUTLET] -outline {} -fill {}
    $cnv create text 0 0 -anchor w -tags [list ${tag} ${tag}LABEL label text]

    ::pd::widget::widgetbehaviour $obj config ::pd::widget::bang::config
    ::pd::widget::widgetbehaviour $obj select ::pd::widget::bang::select
}
proc ::pd::widget::bang::config {obj args} {
    set options [::pd::widget::parseargs \
                     {
                         -labelpos 2
                         -size 2
                         -colors 3
                         -font 2
                         -label 1
                     } $args]
    set tag [::pd::widget::base_tag $obj]

foreach cnv [::pd::widget::get_canvases $obj] {
    set zoom [::pdtk_canvas::get_zoom $cnv]
    set iow $::pd::widget::IOWIDTH
    set ih [expr $::pd::widget::IHEIGHT - 0.5]
    set oh [expr $::pd::widget::OHEIGHT - 1]
    dict for {k v} $options {
        foreach {xpos ypos _ _} [$cnv coords "${tag}"] {break}
        switch -exact -- $k {
            default {
            } "-labelpos" {
                set xnew [lindex $v 0]
                set ynew [lindex $v 1]
                $cnv coords "${tag}LABEL" \
                    [expr $xpos + $xnew * $zoom] [expr $ypos + $ynew * $zoom]
            } "-size" {
                set xnew [lindex $v 0]
                set ynew [lindex $v 1]
                $cnv coords "${tag}BASE" \
                          $xpos                        $ypos                  \
                    [expr $xpos + $xnew * $zoom] [expr $ypos + $ynew * $zoom]
                $cnv coords "${tag}BUT" \
                    [expr $xpos +                 $zoom] [expr $ypos +                 $zoom] \
                    [expr $xpos + ($xnew - 1.5) * $zoom] [expr $ypos + ($ynew - 1.5) * $zoom]

                $cnv coords "${tag}INLET" \
                          $xpos                       $ypos                          \
                    [expr $xpos + $iow * $zoom] [expr $ypos +           $ih * $zoom]
                $cnv coords "${tag}OUTLET" \
                          $xpos                 [expr $ypos + ($ynew - $oh) * $zoom] \
                    [expr $xpos + $iow * $zoom] [expr $ypos + ($ynew      ) * $zoom]
            } "-colors" {
                set color [lindex $v 0]
                $cnv itemconfigure "${tag}BASE" -fill $color
                if { [$cnv itemcget "${tag}BUT" -fill] ne {} } {
                    set color [lindex $v 1]
                    $cnv itemconfigure "${tag}BUT" -fill $color
                }
                set color [lindex $v 2]
                $cnv itemconfigure "${tag}LABEL" -fill $color
            } "-font" {
                set fontweight $::font_weight
                set font [lindex $v 0]
                set fontsize [lindex $v 1]
                set fontsize [expr -int($fontsize) * $zoom]
                $cnv itemconfigure "${tag}LABEL" -font [list $font $fontsize $fontweight]
            } "-label" {
                pdtk_text_set $cnv "${tag}LABEL" $v
            }

        }
        $cnv itemconfigure "${tag}BASE" -width $zoom
        $cnv itemconfigure "${tag}BUT" -width $zoom
    }
}
}
proc ::pd::widget::bang::select {obj state} {
    # if selection is activated, use a different color
    # TODO: label

    if {$state != 0} {
        set color #0000FF
    } else {
        set color #000000
    }
    set tag "[::pd::widget::base_tag $obj]"
    foreach cnv [::pd::widget::get_canvases $obj] {
        $cnv itemconfigure "${tag}BASE" -outline $color
        $cnv itemconfigure "${tag}BUT" -outline $color
    }
}

proc ::pd::widget::bang::activate {obj state activecolor} {
    # LATER: have the timer work on the GUI side!
    set tag "[::pd::widget::base_tag $obj]BUT"
    if {! $state} {
        set activecolor {}
    }
    foreach cnv [::pd::widget::get_canvases $obj] {
        $cnv itemconfigure $tag -fill $activecolor
    }
}



::pd::widget::register bang ::pd::widget::bang::create