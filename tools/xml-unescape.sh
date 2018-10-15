#!/bin/bash

function HTMLtoText () {
    LineOut=$1  # Parm 1= Input line
    LineOut="${LineOut//&nbsp;/ }"
    LineOut="${LineOut//&amp;/&}"
    LineOut="${LineOut//&lt;/<}"
    LineOut="${LineOut//&gt;/>}"
    LineOut="${LineOut//&quot;/'"'}"
    LineOut="${LineOut//&#39;/"'"}"
    LineOut="${LineOut//&ldquo;/'"'}" # TODO: ASCII/ISO for opening quote
    LineOut="${LineOut//&rdquo;/'"'}" # TODO: ASCII/ISO for closing quote
    echo $LineOut 
} 

HTMLtoText "$*"

