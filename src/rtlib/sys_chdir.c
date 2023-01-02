/* chdir function */

#include "fb.h"

#ifdef HOST_MINGW
#include <direct.h>
#elif defined(HOST_FB_BLACKBOX)
int HOST_FB_BLACKBOX_fb_ChDir(const char* path);
#else
#include <unistd.h>
#endif

FBCALL int fb_ChDir( FBSTRING *path )
{
	int res;

#ifdef HOST_MINGW
	res = _chdir( path->data );
	#elif defined(HOST_FB_BLACKBOX)
	res = HOST_FB_BLACKBOX_fb_ChDir(path->data);
#else
	res = chdir( path->data );
#endif

	/* del if temp */
	fb_hStrDelTemp( path );

	return res;
}
