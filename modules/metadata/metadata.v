module metadata

import v.vmod

const manifest = vmod.from_file('v.mod') or { 
	eprintln(err) 
	exit(1)
}

pub const (
	version     = manifest.version
	name        = manifest.name
	description = manifest.description
)
