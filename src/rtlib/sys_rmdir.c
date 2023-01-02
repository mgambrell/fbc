/* rmdir function */

#include "fb.h"

#ifdef HOST_MINGW
#include <direct.h>
#elif defined(HOST_FB_BLACKBOX)
int HOST_FB_BLACKBOX_fb_RmDir(const char* path);
#else
#include <unistd.h>
#endif

/*:::::*/
FBCALL int fb_RmDir( FBSTRING *path )
{
	int res;

#ifdef HOST_MINGW
	res = _rmdir( path->data );
#elif defined(HOST_FB_BLACKBOX)
	res = HOST_FB_BLACKBOX_fb_RmDir(path->data);
#else
	res = rmdir( path->data );
#endif

	/* del if temp */
	fb_hStrDelTemp( path );

	return res;
}

