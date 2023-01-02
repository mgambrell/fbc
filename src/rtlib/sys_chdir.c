/* chdir function */

#include "fb.h"

/* blackbox systems don't have chdir, so private implementation is needed */
/* TODO: make blackbox API instead so common string handling etc. are handled here */
#ifndef HOST_FB_BLACKBOX

#ifdef HOST_MINGW
#include <direct.h>
#else
#include <unistd.h>
#endif

FBCALL int fb_ChDir( FBSTRING *path )
{
	int res;

#ifdef HOST_MINGW
	res = _chdir( path->data );
#else
	res = chdir( path->data );
#endif

	/* del if temp */
	fb_hStrDelTemp( path );

	return res;
}

#endif
