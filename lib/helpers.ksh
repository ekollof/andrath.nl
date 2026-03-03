# lib/helpers.ksh — shared helper functions
# Sourced by publish.ksh; relies on globals set there.

# ---------------------------------------------------------------------------
# month_to_num "March" varname
# Sets varname to the zero-padded month number ("03").
# ---------------------------------------------------------------------------
month_to_num() {
    _mtn_name="$1"; _mtn_var="${2:-_month_num}"
    case "$_mtn_name" in
        January)   eval "$_mtn_var=01" ;; February)  eval "$_mtn_var=02" ;;
        March)     eval "$_mtn_var=03" ;; April)     eval "$_mtn_var=04" ;;
        May)       eval "$_mtn_var=05" ;; June)      eval "$_mtn_var=06" ;;
        July)      eval "$_mtn_var=07" ;; August)    eval "$_mtn_var=08" ;;
        September) eval "$_mtn_var=09" ;; October)   eval "$_mtn_var=10" ;;
        November)  eval "$_mtn_var=11" ;; December)  eval "$_mtn_var=12" ;;
        *)         eval "$_mtn_var=00" ;;
    esac
}

# ---------------------------------------------------------------------------
# parse_date_line "March 03, 2026 11:01:32" yr_var mo_var dy_var tm_var
# Parses a .DA line into year/month/day/time variables.
# ---------------------------------------------------------------------------
parse_date_line() {
    _pdl_line="$1"
    _pdl_yr_var="${2:-_yr}"; _pdl_mo_var="${3:-_mo}"
    _pdl_dy_var="${4:-_dy}"; _pdl_tm_var="${5:-_tm}"

    _pdl_last=$(echo "$_pdl_line" | awk '{print $NF}')
    if echo "$_pdl_last" | grep -qE '^[0-2][0-9]:[0-5][0-9]:[0-5][0-9]$'; then
        _pdl_date=$(echo "$_pdl_line" | awk '{$NF=""; sub(/ *$/, ""); print}')
        _pdl_time="$_pdl_last"
    else
        _pdl_date="$_pdl_line"; _pdl_time="00:00:00"
    fi

    if [ -z "$_pdl_date" ]; then
        eval "$_pdl_yr_var=0000"; eval "$_pdl_mo_var=00"
        eval "$_pdl_dy_var=00";   eval "$_pdl_tm_var=00:00:00"
        return
    fi

    _pdl_mn=$(echo "$_pdl_date" | awk '{print $1}')
    _pdl_d=$(echo "$_pdl_date"  | awk '{print $2}' | tr -d ',')
    _pdl_y=$(echo "$_pdl_date"  | awk '{print $3}')
    [ "${#_pdl_d}" -eq 1 ] && _pdl_d="0$_pdl_d"
    month_to_num "$_pdl_mn" _pdl_mnum
    eval "$_pdl_yr_var=$_pdl_y"; eval "$_pdl_mo_var=$_pdl_mnum"
    eval "$_pdl_dy_var=$_pdl_d"; eval "$_pdl_tm_var=$_pdl_time"
}

# ---------------------------------------------------------------------------
# process_ms src.ms output_file
# Runs the groff pipeline and writes body HTML to output_file.
# ---------------------------------------------------------------------------
process_ms() {
    _pm_src="$1"; _pm_out="$2"
    perl preprocess-code.pl "$_pm_src" > temp_preprocessed.ms
    groff -ms -mwww -Thtml temp_preprocessed.ms > temp_groff.html
    perl normalize-html.pl temp_groff.html > temp_normalized.html
    sed -n '/<body>/,/<\/body>/p' temp_normalized.html \
    | sed -e '1d' -e '$d' \
          -e '/<h1 align="center">/d' \
          -e 's|<p\(.*\)>\(.*\)</p>|<p\1 data-text="\2">\2</p>|g' \
    > "$_pm_out"
    rm -f temp_preprocessed.ms temp_groff.html temp_normalized.html
}

# ---------------------------------------------------------------------------
# num_to_month_name "03" varname
# Sets varname to the full English month name.
# ---------------------------------------------------------------------------
num_to_month_name() {
    _nmn_num="$1"; _nmn_var="${2:-_mname}"
    case "$_nmn_num" in
        01) eval "$_nmn_var=January"   ;; 02) eval "$_nmn_var=February"  ;;
        03) eval "$_nmn_var=March"     ;; 04) eval "$_nmn_var=April"     ;;
        05) eval "$_nmn_var=May"       ;; 06) eval "$_nmn_var=June"      ;;
        07) eval "$_nmn_var=July"      ;; 08) eval "$_nmn_var=August"    ;;
        09) eval "$_nmn_var=September" ;; 10) eval "$_nmn_var=October"   ;;
        11) eval "$_nmn_var=November"  ;; 12) eval "$_nmn_var=December"  ;;
        *)  eval "$_nmn_var=Unknown"   ;;
    esac
}

# ---------------------------------------------------------------------------
# num_to_month_abbr "03" varname
# Sets varname to the 3-letter abbreviated month name.
# ---------------------------------------------------------------------------
num_to_month_abbr() {
    _nma_num="$1"; _nma_var="${2:-_mabbr}"
    case "$_nma_num" in
        01) eval "$_nma_var=Jan" ;; 02) eval "$_nma_var=Feb" ;;
        03) eval "$_nma_var=Mar" ;; 04) eval "$_nma_var=Apr" ;;
        05) eval "$_nma_var=May" ;; 06) eval "$_nma_var=Jun" ;;
        07) eval "$_nma_var=Jul" ;; 08) eval "$_nma_var=Aug" ;;
        09) eval "$_nma_var=Sep" ;; 10) eval "$_nma_var=Oct" ;;
        11) eval "$_nma_var=Nov" ;; 12) eval "$_nma_var=Dec" ;;
        *)  eval "$_nma_var=Jan" ;;
    esac
}
