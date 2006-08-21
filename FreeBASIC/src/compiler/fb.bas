''	FreeBASIC - 32-bit BASIC Compiler.
''	Copyright (C) 2004-2006 Andre Victor T. Vicentini (av1ctor@yahoo.com.br)
''
''	This program is free software; you can redistribute it and/or modify
''	it under the terms of the GNU General Public License as published by
''	the Free Software Foundation; either version 2 of the License, or
''	(at your option) any later version.
''
''	This program is distributed in the hope that it will be useful,
''	but WITHOUT ANY WARRANTY; without even the implied warranty of
''	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
''	GNU General Public License for more details.
''
''	You should have received a copy of the GNU General Public License
''	along with this program; if not, write to the Free Software
''	Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA.


'' fb - main interface
''
'' chng: sep/2004 written [v1ctor]


#include once "inc\fb.bi"
#include once "inc\fbint.bi"
#include once "inc\parser.bi"
#include once "inc\lex.bi"
#include once "inc\rtl.bi"
#include once "inc\ast.bi"
#include once "inc\ir.bi"
#include once "inc\emit.bi"
#include once "inc\emitdbg.bi"

type FB_LANG_INFO
	name		as zstring ptr
	options		as FB_LANG_OPT
end type

declare sub		 parserInit				( )

declare sub		 parserEnd				( )


'' globals
	dim shared infileTb( ) as FBFILE
	dim shared incpathTB( ) as zstring * FB_MAXPATHLEN+1
	dim shared pathTB(0 to FB_MAXPATHS-1) as zstring * FB_MAXPATHLEN+1

	dim shared as FB_LANG_INFO langTb(0 to FB_LANGS-1) = _
	{ _
		( _
			@"fb", _
			FB_LANG_OPT_MT or _
			FB_LANG_OPT_SCOPE or _
			FB_LANG_OPT_NAMESPC or _
			FB_LANG_OPT_EXTERN or _
			FB_LANG_OPT_FUNCOVL or _
			FB_LANG_OPT_OPEROVL or _
			FB_LANG_OPT_CLASS or _
			FB_LANG_OPT_INITIALIZER or _
			FB_LANG_OPT_SINGERRLINE or _
			FB_LANG_OPT_ALWAYSOVL or _
			FB_LANG_OPT_QUIRKFUNC _
		) _
		, _
		( _
			@"deprecated", _
			FB_LANG_OPT_MT or _
			FB_LANG_OPT_SCOPE or _
			FB_LANG_OPT_NAMESPC or _
			FB_LANG_OPT_EXTERN or _
			FB_LANG_OPT_FUNCOVL or _
			FB_LANG_OPT_INITIALIZER or _
			FB_LANG_OPT_CALL or _
			FB_LANG_OPT_LET or _
			FB_LANG_OPT_PERIODS or _
			FB_LANG_OPT_NUMLABEL or _
            FB_LANG_OPT_IMPLICIT or _
            FB_LANG_OPT_DEFTYPE or _
            FB_LANG_OPT_SUFFIX or _
            FB_LANG_OPT_METACMD or _
    		FB_LANG_OPT_QBOPT or _
    		FB_LANG_OPT_DEPRECTOPT or _
    		FB_LANG_OPT_ONERROR or _
    		FB_LANG_OPT_QUIRKFUNC _
		) _
		, _
		( _
			@"qb", _
			FB_LANG_OPT_GOSUB or _
			FB_LANG_OPT_CALL or _
			FB_LANG_OPT_LET or _
			FB_LANG_OPT_PERIODS or _
			FB_LANG_OPT_NUMLABEL or _
            FB_LANG_OPT_IMPLICIT or _
            FB_LANG_OPT_DEFTYPE or _
            FB_LANG_OPT_SUFFIX or _
            FB_LANG_OPT_METACMD or _
    		FB_LANG_OPT_QBOPT or _
    		FB_LANG_OPT_ONERROR or _
    		FB_LANG_OPT_SHAREDLOCAL or _
    		FB_LANG_OPT_QUIRKFUNC _
		) _
		, _
		( _
			@"vb", _
			FB_LANG_OPT_MT or _
			FB_LANG_OPT_NAMESPC or _
			FB_LANG_OPT_EXTERN or _
			FB_LANG_OPT_FUNCOVL or _
			FB_LANG_OPT_INITIALIZER or _
			FB_LANG_OPT_CALL or _
			FB_LANG_OPT_LET or _
            FB_LANG_OPT_IMPLICIT or _
            FB_LANG_OPT_DEFTYPE or _
            FB_LANG_OPT_METACMD or _
    		FB_LANG_OPT_QBOPT or _
    		FB_LANG_OPT_DEPRECTOPT or _
    		FB_LANG_OPT_ONERROR or _
    		FB_LANG_OPT_VBSYMB or _
    		FB_LANG_OPT_QUIRKFUNC _
		) _
	}

'' const
#if defined(TARGET_WIN32) or defined(TARGET_DOS) or defined(TARGET_XBOX)
	const PATHDIV = RSLASH
#else
	const PATHDIV = "/"
#endif

''::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' interface
''::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

'':::::
sub fbAddIncPath _
	( _
		byval path as zstring ptr _
	)

	if( env.incpaths < FB_MAXINCPATHS ) then
        ' test for both path dividers because a slash is also supported
        ' under Win32 and DOS using DJGPP. However, the (back)slashes
        ' will always be converted to the OS' preferred type of slash.
		select case right( *path, 1 )
        case "/", RSLASH
        case else
			*path += PATHDIV
		end select

		incpathTB( env.incpaths ) = *path

		env.incpaths += 1
	end if

end sub

'':::::
sub fbAddDefine _
	( _
		byval dname as zstring ptr, _
		byval dtext as zstring ptr _
	)

    symbAddDefine( dname, dtext, len( *dtext ) )

end sub

'':::::
private function hFindIncFile _
	( _
		byval filename as zstring ptr _
	) as zstring ptr static

	dim as string fname

	fname = ucase( *filename )

	function = hashLookup( @env.incfilehash, fname )

end function

'':::::
private function hAddIncFile _
	( _
		byval filename as zstring ptr _
	) as zstring ptr static

    dim as zstring ptr fname, res
    dim as uinteger index

	fname = allocate( len( *filename ) + 1 )
	hUcase( filename, fname )

	index = hashHash( fname )

	res = hashLookupEx( @env.incfilehash, fname, index )
	if( res = NULL ) then
		hashAdd( @env.incfilehash, fname, fname, index )
	else
		deallocate( fname )
		fname = res
	end if

	function = fname

end function

'':::::
private sub hSetLangOptions _
	( _
		byval lang as FB_LANG _
	)

	env.langopt = langTb(lang).options

end sub

'':::::
function fbGetLangOptions _
	( _
		byval lang as FB_LANG _
	) as FB_LANG_OPT

	function = langTb(lang).options

end function

'':::::
function fbGetLangName _
	( _
		byval lang as FB_LANG _
	) as string

	function = *langTb(lang).name

end function

'':::::
private sub hSetLangCtx _
	( _
		byval lang as FB_LANG _
	)

	if( lang = FB_LANG_FB ) then
		env.opt.parammode = FB_PARAMMODE_BYVAL
		env.opt.explicit = TRUE
	else
		env.opt.parammode = FB_PARAMMODE_BYREF
		env.opt.explicit = FALSE
	end if

	env.opt.procpublic		= TRUE
	env.opt.escapestr		= FALSE
	env.opt.dynamic			= FALSE
	env.opt.base = 0

end sub

'':::::
private sub hSetCtx( )

	env.scope				= FB_MAINSCOPE
	env.includerec			= 0
	env.currproc 			= NULL
	env.currblock 			= NULL

	env.mangling			= FB_MANGLING_BASIC
	env.currlib				= NULL

	env.main.proc			= NULL

	hSetLangCtx( env.clopt.lang )

	env.stmtcnt				= 0

	env.prntcnt				= 0
	env.prntopt				= FALSE
	env.checkarray			= TRUE
	env.ctxsym 				= NULL
	env.isexpr 				= FALSE
	env.isscope				= FALSE

	''
	env.stmt.for.cmplabel	= NULL
	env.stmt.for.endlabel	= NULL
	env.stmt.do.cmplabel	= NULL
	env.stmt.do.endlabel	= NULL
	env.stmt.while.cmplabel	= NULL
	env.stmt.while.endlabel	= NULL
	env.stmt.select.cmplabel= NULL
	env.stmt.select.endlabel= NULL
	env.stmt.proc.cmplabel	= NULL
	env.stmt.proc.endlabel	= NULL
	env.stmt.with.sym		= NULL

	''
	env.incpaths			= 0

	fbAddIncPath( exepath( ) + *fbGetPath( FB_PATH_INC ) )

	''
	select case env.clopt.target
	case FB_COMPTARGET_WIN32, FB_COMPTARGET_CYGWIN
		env.target.wchar.type = FB_DATATYPE_USHORT
		env.target.wchar.size = 2
	case FB_COMPTARGET_DOS
		env.target.wchar.type = FB_DATATYPE_UBYTE
		env.target.wchar.size = 1
	case else
		env.target.wchar.type = FB_DATATYPE_UINT
		env.target.wchar.size = FB_INTEGERSIZE
	end select

	env.target.wchar.doconv = ( len( wstring ) = env.target.wchar.size )

end sub

'':::::
private sub incTbInit( )

	hashInit( )

	hashNew( @env.incfilehash, FB_INITINCFILES, TRUE )

end sub

'':::::
private sub incTbEnd( )

	hashFree( @env.incfilehash )

	hashEnd( )

end sub

'':::::
private sub stmtStackInit( )

	stackNew( @env.stmtstk, FB_INITSTMTSTACKNODES, len( FB_CMPSTMTSTK ), FALSE )

end sub

'':::::
private sub stmtStackEnd( )

	stackFree( @env.stmtstk )

end sub

'':::::
function fbInit _
	( _
		byval ismain as integer _
	) as integer static

	function = FALSE

	''
	redim infileTb( 0 to FB_MAXINCRECLEVEL-1 )

	redim incpathTB( 0 to FB_MAXINCPATHS-1 )

	''
	hSetCtx( )

	''
	symbInit( ismain )

	hlpInit( )

	errInit( )

	astInit( )

	irInit( )

	emitInit( )

	inctbInit( )

	stmtStackInit( )

	lexInit( FALSE )

	parserInit( )

	rtlInit( )

	''
	function = TRUE

end function

'':::::
sub fbEnd

	''
	rtlEnd( )

	parserEnd( )

	lexEnd( )

	stmtStackEnd( )

	incTbEnd( )

	emitEnd( )

	irEnd( )

	astEnd( )

	errEnd( )

	hlpEnd( )

	symbEnd( )

	''
	erase incpathTB

	erase infileTb

end sub

'':::::
sub fbSetDefaultOptions( )

	env.clopt.debug			= FALSE
	env.clopt.cputype 		= FB_DEFAULT_CPUTYPE
	env.clopt.errorcheck	= FALSE
	env.clopt.resumeerr 	= FALSE
#if defined(TARGET_WIN32) or defined(TARGET_CYGWIN)
	env.clopt.nostdcall 	= FALSE
#else
	env.clopt.nostdcall 	= TRUE
#endif
	env.clopt.nounderprefix	= FALSE
	env.clopt.outtype		= FB_DEFAULT_OUTTYPE
	env.clopt.warninglevel 	= 0
	env.clopt.export		= FALSE
	env.clopt.nodeflibs		= FALSE
	env.clopt.showerror		= TRUE
	env.clopt.multithreaded	= FALSE
	env.clopt.profile       = FALSE
	env.clopt.target		= FB_DEFAULT_TARGET
	env.clopt.extraerrchk	= FALSE
	env.clopt.msbitfields	= FALSE
	env.clopt.maxerrors		= FB_DEFAULT_MAXERRORS
	env.clopt.showsusperrors= FALSE
	env.clopt.lang			= FB_LANG_FB
	env.clopt.pdcheckopt	= FB_PDCHECK_NONE

	hSetLangOptions( env.clopt.lang )

end sub

'':::::
sub fbSetOption _
	( _
		byval opt as integer, _
		byval value as integer _
	)

	select case as const opt
	case FB_COMPOPT_DEBUG
		env.clopt.debug = value

	case FB_COMPOPT_CPUTYPE
		env.clopt.cputype = value

	case FB_COMPOPT_ERRORCHECK
		env.clopt.errorcheck = value

	case FB_COMPOPT_NOSTDCALL
		env.clopt.nostdcall = value

	case FB_COMPOPT_NOUNDERPREFIX
		env.clopt.nounderprefix = value

	case FB_COMPOPT_OUTTYPE
		env.clopt.outtype = value

	case FB_COMPOPT_RESUMEERROR
		env.clopt.resumeerr = value

	case FB_COMPOPT_WARNINGLEVEL
		env.clopt.warninglevel = value

	case FB_COMPOPT_EXPORT
		env.clopt.export = value

	case FB_COMPOPT_NODEFLIBS
		env.clopt.nodeflibs = value

	case FB_COMPOPT_SHOWERROR
		env.clopt.showerror = value

	case FB_COMPOPT_MULTITHREADED
		env.clopt.multithreaded = value

	case FB_COMPOPT_PROFILE
		env.clopt.profile = value

	case FB_COMPOPT_TARGET
		env.clopt.target = value

	case FB_COMPOPT_EXTRAERRCHECK
		env.clopt.extraerrchk = value

	case FB_COMPOPT_MSBITFIELDS
		env.clopt.msbitfields = value

	case FB_COMPOPT_MAXERRORS
		env.clopt.maxerrors = value

	case FB_COMPOPT_SHOWSUSPERRORS
		env.clopt.showsusperrors = value

	case FB_COMPOPT_LANG
		env.clopt.lang = value
		hSetLangOptions( value )

	case FB_COMPOPT_PEDANTICCHK
		env.clopt.pdcheckopt = value
	end select

end sub

'':::::
function fbGetOption _
	( _
		byval opt as integer _
	) as integer

	select case as const opt
	case FB_COMPOPT_DEBUG
		function = env.clopt.debug

	case FB_COMPOPT_CPUTYPE
		function = env.clopt.cputype

	case FB_COMPOPT_ERRORCHECK
		function = env.clopt.errorcheck

	case FB_COMPOPT_NOSTDCALL
		function = env.clopt.nostdcall

	case FB_COMPOPT_NOUNDERPREFIX
		function = env.clopt.nounderprefix

	case FB_COMPOPT_OUTTYPE
		function = env.clopt.outtype

	case FB_COMPOPT_RESUMEERROR
		function = env.clopt.resumeerr

	case FB_COMPOPT_WARNINGLEVEL
		function = env.clopt.warninglevel

	case FB_COMPOPT_EXPORT
		function = env.clopt.export

	case FB_COMPOPT_NODEFLIBS
		function = env.clopt.nodeflibs

	case FB_COMPOPT_SHOWERROR
		function = env.clopt.showerror

	case FB_COMPOPT_MULTITHREADED
		function = env.clopt.multithreaded

	case FB_COMPOPT_PROFILE
		function = env.clopt.profile

	case FB_COMPOPT_TARGET
		function = env.clopt.target

	case FB_COMPOPT_EXTRAERRCHECK
		function = env.clopt.extraerrchk

	case FB_COMPOPT_MSBITFIELDS
		function = env.clopt.msbitfields

	case FB_COMPOPT_MAXERRORS
		function = env.clopt.maxerrors

	case FB_COMPOPT_SHOWSUSPERRORS
		function = env.clopt.showsusperrors

	case FB_COMPOPT_LANG
		function = env.clopt.lang

	case FB_COMPOPT_PEDANTICCHK
		function = env.clopt.pdcheckopt

	case else
		function = FALSE
	end select

end function

'':::::
sub fbSetPaths _
	( _
		byval target as integer _
	) static

	select case as const target
	case FB_COMPTARGET_WIN32
		pathTB(FB_PATH_BIN) = FB_BINPATH + "win32" + RSLASH
		pathTB(FB_PATH_INC) = FB_INCPATH
		pathTB(FB_PATH_LIB) = FB_LIBPATH + "win32"

	case FB_COMPTARGET_CYGWIN
		pathTB(FB_PATH_BIN) = FB_BINPATH + "cygwin" + RSLASH
		pathTB(FB_PATH_INC) = FB_INCPATH
		pathTB(FB_PATH_LIB) = FB_LIBPATH + "cygwin"

	case FB_COMPTARGET_DOS
		pathTB(FB_PATH_BIN)	= FB_BINPATH + "dos" + RSLASH
		pathTB(FB_PATH_INC)	= FB_INCPATH
		pathTB(FB_PATH_LIB)	= FB_LIBPATH + "dos"

	case FB_COMPTARGET_LINUX
		pathTB(FB_PATH_BIN) = FB_BINPATH + "linux" + RSLASH
		pathTB(FB_PATH_INC) = FB_INCPATH
		pathTB(FB_PATH_LIB) = FB_LIBPATH + "linux"

	case FB_COMPTARGET_XBOX
		pathTB(FB_PATH_BIN) = FB_BINPATH + "win32" + RSLASH
		pathTB(FB_PATH_INC) = FB_INCPATH
		pathTB(FB_PATH_LIB) = FB_LIBPATH + "xbox"
	end select

#ifdef TARGET_LINUX
	hRevertSlash( pathTB(FB_PATH_BIN), FALSE )
	hRevertSlash( pathTB(FB_PATH_INC), FALSE )
	hRevertSlash( pathTB(FB_PATH_LIB), FALSE )
#endif

end sub

'':::::
function fbGetPath _
	( _
		byval path as integer _
	) as zstring ptr static

	function = @pathTB( path )

end function

'':::::
function fbGetEntryPoint( ) as string static

	select case env.clopt.target
	case FB_COMPTARGET_XBOX
		return "XBoxStartup"

	case else
		return "main"

	end select

end function

'':::::
function fbGetModuleEntry( ) as string static
    dim as string sname

   	sname = hStripPath( hStripExt( env.outf.name ) )

   	hClearName( sname )

	function = "fb_ctor__" + sname

end function

'':::::
function fbPreInclude _
	( _
		preincTb() as string, _
		byval preincfiles as integer _
	) as integer

	dim as integer i

	for i = 0 to preincfiles-1
		if( fbIncludeFile( preincTb(i), TRUE ) = FALSE ) then
			return FALSE
		end if
	next

	function = TRUE

end function

'':::::
function fbCompile _
	( _
		byval infname as zstring ptr, _
		byval outfname as zstring ptr, _
		byval ismain as integer, _
		preincTb() as string, _
		byval preincfiles as integer _
	) as integer

    dim as integer res
	dim as double tmr

	function = FALSE

	''
	env.inf.name	= *hRevertSlash( infname, FALSE )
	env.inf.incfile	= NULL
	env.inf.ismain	= ismain

	env.outf.name	= *outfname
	env.outf.ismain = ismain

	'' open source file
	if( hFileExists( *infname ) = FALSE ) then
		errReportEx( FB_ERRMSG_FILENOTFOUND, infname, -1 )
		exit function
	end if

	env.inf.num = freefile
	if( open( *infname, for binary, access read, as #env.inf.num ) <> 0 ) then
		errReportEx( FB_ERRMSG_FILEACCESSERROR, infname, -1 )
		exit function
	end if

	env.inf.format = hCheckFileFormat( env.inf.num )

	''
	if( emitOpen( ) = FALSE ) then
		errReportEx( FB_ERRMSG_FILEACCESSERROR, infname, -1 )
		exit function
	end if

	fbMainBegin( )

	tmr = timer( )

	res = fbPreInclude( preincTb(), preincfiles )

	if( res = TRUE ) then
		'' parse
		res = cProgram( )
	end if

	tmr = timer( ) - tmr

	fbMainEnd( )

	'' save
	emitClose( tmr )

	'' close src
	if( close( #env.inf.num ) <> 0 ) then
		'' ...
	end if

	'' check if any label undefined was used
	if( res = TRUE ) then
		symbCheckLabels( )
		function = (errGetCount( ) = 0)
	else
		function = FALSE
	end if

end function

'':::::
function fbListLibs _
	( _
		namelist() as string, _
		byval index as integer _
	) as integer

	dim as integer i

	index += symbListLibs( namelist(), index )

	if( env.clopt.multithreaded ) then
		for i = 0 to index-1
			if( namelist(i) = "fb" ) then
				namelist(i) = "fbmt"
				exit for
			end if
		next
	end if

	function = index

end function

'':::::
sub fbAddDefaultLibs( ) static

	if( env.clopt.nodeflibs ) then
		exit sub
    end if

	symbAddLib( "fb" )

	select case as const env.clopt.target
	case FB_COMPTARGET_WIN32
		symbAddLib( "gcc" )
		symbAddLib( "msvcrt" )
		symbAddLib( "kernel32" )
		symbAddLib( "mingw32" )
		symbAddLib( "mingwex" )
		symbAddLib( "moldname" )

	case FB_COMPTARGET_CYGWIN
		symbAddLib( "gcc" )
		symbAddLib( "cygwin" )
		symbAddLib( "kernel32" )

	case FB_COMPTARGET_LINUX
		symbAddLib( "gcc" )
		symbAddLib( "c" )
		symbAddLib( "m" )
		symbAddLib( "pthread" )
		symbAddLib( "dl" )
		symbAddLib( "ncurses" )

	case FB_COMPTARGET_DOS
		symbAddLib( "gcc" )
		symbAddLib( "c" )
		symbAddLib( "m" )

	case FB_COMPTARGET_XBOX
		symbAddLib( "gcc" )
		symbAddLib( "fbgfx" )
		symbAddLib( "SDL" )
		symbAddLib( "openxdk" )
		symbAddLib( "hal" )
		symbAddLib( "c" )
		symbAddLib( "usb" )
		symbAddLib( "xboxkrnl" )
		symbAddLib( "m" )

	end select

end sub

''::::
function fbIncludeFile _
	( _
		byval filename as zstring ptr, _
		byval isonce as integer _
	) as integer

    static as zstring * FB_MAXPATHLEN incfile
    dim as zstring ptr fileidx
    dim as integer i

	function = FALSE

	if( env.includerec >= FB_MAXINCRECLEVEL ) then
		errReport( FB_ERRMSG_RECLEVELTOODEEP )
		return errFatal( )
	end if

	'' 1st) try finding it at same path as the current source-file
	incfile = hStripFilename( env.inf.name )
	incfile += *filename

	if( hFileExists( incfile ) = FALSE ) then

		'' 2nd) try as-is (could include an absolute or relative path)
		if( hFileExists( filename ) = FALSE ) then

			'' 3rd) try finding it at the inc paths
			for i = env.incpaths-1 to 0 step -1
				incfile = incpathTB(i)
				incfile += *filename
				if( hFileExists( incfile ) ) then
					exit for
				end if
			next

			'' not found?
			if( i < 0 ) then
				errReportEx( FB_ERRMSG_FILENOTFOUND, QUOTE + *filename + QUOTE )
				return errFatal( )
			end if

		else
			incfile = *filename
		end if
	end if

	''
	hRevertSlash( incfile, FALSE )

	''
	if( isonce ) then
           '' we should respect the path
       	if( hFindIncFile( incfile ) <> NULL ) then
       		return TRUE
       	end if
	end if

    '' we should respect the path here too
	fileidx = hAddIncFile( incfile )

	'' push context
	infileTb(env.includerec) = env.inf
   	env.includerec += 1

	env.inf.name  = incfile
	env.inf.incfile = fileidx

	''
	env.inf.num = freefile
	if( open( incfile, for binary, access read, as #env.inf.num ) <> 0 ) then
		errReportEx( FB_ERRMSG_FILENOTFOUND, QUOTE + *filename + QUOTE )
		return errFatal( )
	end if

	env.inf.format = hCheckFileFormat( env.inf.num )

	'' parse
	lexPushCtx( )

	lexInit( TRUE )

	function = cProgram( )

	lexPopCtx( )

	'' close it
	if( close( #env.inf.num ) <> 0 ) then
		'' ...
	end if

	'' pop context
	env.includerec -= 1
	env.inf = infileTb( env.includerec )

end function

'':::::
sub fbReportRtError _
	( _
		byval modname as zstring ptr, _
		byval funname as zstring ptr, _
		byval errnum as integer _
	) static

	print

	print "Internal compiler error"; errnum;
	if( modname <> NULL ) then
		print " at "; *modname; "::";
		if( funname <> NULL ) then
			print *funname;
		end if
	end if
	print " while parsing "; env.inf.name;
	if( env.currproc <> NULL ) then
		print ":"; *symbGetName( env.currproc );
	end if
	print "("; cuint( lexLineNum( ) ); ")"

	print

end sub


