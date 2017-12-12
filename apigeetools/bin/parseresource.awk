BEGIN { resval=""; }

/:Variable.*name="resource"/ {
	re= "\"[ ]*[x/]"
	resval = substr ( $0, (m = match($0, "value=\"")+7), (x = (match($0, re) - m)) )
	if (cmd == "dbg") print "  resval: " resval " m: " m " length: " length($0) " x: " x
}

/.*\/applications\/.*\/active/ {
	split($0, chunks, "/")
	module=chunks[3]
	print module "," resval
#	resval=""
}

END {
	if ( cmd == "dbg" ) {
		print "parseresource END: " FILENAME
	}
}