/*
 *  libfb - FreeBASIC's runtime library
 *	Copyright (C) 2004-2005 Andre Victor T. Vicentini (av1ctor@yahoo.com.br)
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 *	file_lock - lock and unlock functions
 *
 * chng: nov/2004 written [v1ctor]
 *       jan/2005 os-dep calls moved to proper dirs [v1ctor]
 *
 */

#include "fb.h"
#include "fb_rterr.h"

/*:::::*/
FBCALL int fb_FileLock( int fnum, unsigned int inipos, unsigned int endpos )
{
	FILE 	*f;

	if( fnum < 1 || fnum > FB_MAX_FILES )
		return fb_ErrorSetNum( FB_RTERROR_ILLEGALFUNCTIONCALL );

	f = fb_fileTB[fnum-1].f;

	if( f == NULL )
		return fb_ErrorSetNum( FB_RTERROR_ILLEGALFUNCTIONCALL );

	if( inipos < 1 || endpos <= inipos )
		return fb_ErrorSetNum( FB_RTERROR_ILLEGALFUNCTIONCALL );

	if( fb_fileTB[fnum-1].mode == FB_FILE_MODE_RANDOM )
	{
		inipos = fb_fileTB[fnum-1].len * inipos;
		endpos = inipos + fb_fileTB[fnum-1].len;
	}
	else
	{
		--inipos;
		--endpos;
	}

	return fb_hFileLock( f, inipos, endpos );

}

/*:::::*/
FBCALL int fb_FileUnlock( int fnum, unsigned int inipos, unsigned int endpos )
{
	int 	res;
	FILE 	*f;

	if( fnum < 1 || fnum > FB_MAX_FILES )
		return fb_ErrorSetNum( FB_RTERROR_ILLEGALFUNCTIONCALL );

	f = fb_fileTB[fnum-1].f;

	if( f == NULL )
		return fb_ErrorSetNum( FB_RTERROR_ILLEGALFUNCTIONCALL );

	if( inipos < 1 || endpos <= inipos )
		return fb_ErrorSetNum( FB_RTERROR_ILLEGALFUNCTIONCALL );

	if( fb_fileTB[fnum-1].mode == FB_FILE_MODE_RANDOM )
	{
		inipos = fb_fileTB[fnum-1].len * inipos;
		endpos = inipos + fb_fileTB[fnum-1].len;
	}
	else
	{
		--inipos;
		--endpos;
	}

	return fb_hFileUnlock( f, inipos, endpos );

}

