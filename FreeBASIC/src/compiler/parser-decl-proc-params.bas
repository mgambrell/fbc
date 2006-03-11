''	FreeBASIC - 32-bit BASIC Compiler.
''	Copyright (C) 2004-2005 Andre Victor T. Vicentini (av1ctor@yahoo.com.br)
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


'' proc parameters list declarations (called "arg" by mistake)
''
'' chng: sep/2004 written [v1ctor]

option explicit
option escape

#include once "inc\fb.bi"
#include once "inc\fbint.bi"
#include once "inc\parser.bi"
#include once "inc\ast.bi"

'':::::
''Arguments       =   ArgDecl (',' ArgDecl)* .
''
function cArguments( byval proc as FBSYMBOL ptr, _
					 byval procmode as integer, _
					 byval isproto as integer _
				   ) as FBSYMBOL ptr

	dim as FBSYMBOL ptr arg

	do
		arg = cArgDecl( proc, procmode, isproto )
		if( arg = NULL ) then
			return NULL
		end if

		'' vararg?
		if( arg->arg.mode = FB_ARGMODE_VARARG ) then
			exit do
		end if

	'' ','
	loop while( hMatch( CHAR_COMMA ) )

	function = arg

end function

'':::::
private sub hParamError( byval proc as FBSYMBOL ptr, _
						 byval argnum as integer, _
						 byval argid as zstring ptr )

	hReportParamError( proc, argnum+1, argid, FB_ERRMSG_ILLEGALPARAMSPECAT )

end sub

'':::::
''ArgDecl         =   (BYVAL|BYREF)? ID (('(' ')')? (AS SymbolType)?)? ('=" (NUM_LIT|STR_LIT))? .
''
function cArgDecl( byval proc as FBSYMBOL ptr, _
				   byval procmode as integer, _
				   byval isproto as integer _
				 ) as FBSYMBOL ptr

	static as zstring * FB_MAXNAMELEN+1 idTB(0 to FB_MAXARGRECLEVEL-1)
	static as integer arglevel = 0
	dim as zstring ptr pid
	dim as ASTNODE ptr expr
	dim as integer dclass, dtype, readid, mode, dotpos
	dim as integer atype, amode, alen, asuffix, optional, ptrcnt
	dim as FBVALUE optval
	dim as FBSYMBOL ptr subtype, sym

	function = NULL

	'' "..."?
	if( lexGetToken( ) = FB_TK_VARARG ) then
		'' not cdecl or is it the first arg?
		if( (procmode <> FB_FUNCMODE_CDECL) or _
			(symbGetProcArgs( proc ) = 0) ) then
			hParamError( proc, symbGetProcArgs( proc ), *lexGetText( ) )
			exit function
		end if

		lexSkipToken( )

		return symbAddProcArg( proc, NULL, _
						   	   INVALID, NULL, 0, _
						   	   0, FB_ARGMODE_VARARG, INVALID, _
						   	   FALSE, NULL )
	end if

	'' (BYVAL|BYREF)?
	select case lexGetToken( )
	case FB_TK_BYVAL
		mode = FB_ARGMODE_BYVAL
		lexSkipToken( )
	case FB_TK_BYREF
		mode = FB_ARGMODE_BYREF
		lexSkipToken( )
	case else
		mode = INVALID
	end select

	'' only allow keywords as arg names on prototypes
	readid = TRUE
	if( lexGetClass( ) <> FB_TKCLASS_IDENTIFIER ) then
		if( isproto = FALSE ) then
			'' anything but keywords will be catch by parser (could be a ')' too)
			if( lexGetClass( ) = FB_TKCLASS_KEYWORD ) then
				hParamError( proc, symbGetProcArgs( proc ), *lexGetText( ) )
				exit function
			end if
		end if

		if(	lexGetClass( ) <> FB_TKCLASS_KEYWORD ) then
			if( symbGetProcArgs( proc ) > 0 ) then
				hParamError( proc, symbGetProcArgs( proc ), *lexGetText( ) )
			end if
			exit function
		end if

		if( isproto ) then
			'' AS?
			if( lexGetToken( ) = FB_TK_AS ) then
				readid = FALSE
			end if
		end if
	end if

	''
	if( arglevel >= FB_MAXARGRECLEVEL ) then
		hReportError( FB_ERRMSG_RECLEVELTOODEPTH )
		exit function
	end if

	pid = @idTB(arglevel)

	''
	if( readid ) then
		'' ID
		atype  = lexGetType( )
		dotpos = lexGetPeriodPos( )
		lexEatToken( pid )

		'' ('('')')
		if( hMatch( CHAR_LPRNT ) ) then
			if( (mode <> INVALID) or _
				(hMatch( CHAR_RPRNT ) = FALSE) ) then
				hParamError( proc, symbGetProcArgs( proc ), *pid )
				exit function
			end if

			amode = FB_ARGMODE_BYDESC

		else
			if( mode = INVALID ) then
				amode = env.opt.argmode
			else
				amode = mode
			end if
		end if

	'' no id
	else
		atype  = INVALID
		dotpos = 0

		if( mode = INVALID ) then
			amode = env.opt.argmode
		else
			amode = mode
		end if
	end if

    '' (AS SymbolType)?
    if( hMatch( FB_TK_AS ) ) then
    	if( atype <> INVALID ) then
    		hParamError( proc, symbGetProcArgs( proc ), *pid )
    		exit function
    	end if

    	arglevel += 1
    	if( cSymbolType( atype, subtype, alen, ptrcnt ) = FALSE ) then
    		hParamError( proc, symbGetProcArgs( proc ), *pid )
    		arglevel -= 1
    		exit function
    	end if
    	arglevel -= 1

    	asuffix = INVALID

    else
    	if( readid = FALSE ) then
    		hParamError( proc, symbGetProcArgs( proc ), "" )
    		exit function
    	end if

    	subtype = NULL
    	asuffix = atype
    	ptrcnt = 0
    end if

    ''
    if( atype = INVALID ) then
        atype = hGetDefType( pid )
        asuffix = atype
    end if

    '' check for invalid args
    select case as const atype
    '' can't be a fixed-len string
    case FB_DATATYPE_FIXSTR, FB_DATATYPE_CHAR, FB_DATATYPE_WCHAR
    	hParamError( proc, symbGetProcArgs( proc ), *pid )
    	exit function

	'' can't be as ANY on non-prototypes
    case FB_DATATYPE_VOID
    	if( isproto = FALSE ) then
    		hParamError( proc, symbGetProcArgs( proc ), *pid )
    		exit function
    	end if
    end select

    ''
    select case amode
    case FB_ARGMODE_BYREF, FB_ARGMODE_BYDESC
    	alen = FB_POINTERSIZE

    case FB_ARGMODE_BYVAL

    	'' check for invalid args
    	if( isproto ) then
    		select case atype
    		case FB_DATATYPE_VOID
    			hParamError( proc, symbGetProcArgs( proc ), *pid )
    			exit function
    		end select
    	end if

    	if( atype = FB_DATATYPE_STRING ) then
    		alen = FB_POINTERSIZE
    	else
    		alen = symbCalcLen( atype, subtype, TRUE )
    	end if
    end select

    if( isproto = FALSE ) then
    	'' contains a period?
    	if( dotpos > 0 ) then
    		if( atype = FB_DATATYPE_USERDEF ) then
    			hParamError( proc, symbGetProcArgs( proc ), *pid )
    			exit function
    		end if
    	end if
    end if

    '' ('=' (NUM_LIT|STR_LIT))?
    if( hMatch( FB_TK_ASSIGN ) ) then

    	'' not byval or byref?
    	if( (amode <> FB_ARGMODE_BYVAL) and (amode <> FB_ARGMODE_BYREF) ) then
 	   		hParamError( proc, symbGetProcArgs( proc ), *pid )
    		exit function
    	end if

    	dclass = symbGetDataClass( atype )

    	'' not int, float or string?
    	select case dclass
    	case FB_DATACLASS_INTEGER, FB_DATACLASS_FPOINT, _
    		 FB_DATACLASS_STRING, FB_DATACLASS_UDT

    	case else
 	   		hParamError( proc, symbGetProcArgs( proc ), *pid )
    		exit function
    	end select

    	'' set the context symbol to allow anonymous UDT's
    	dim as FBSYMBOL ptr oldsym = env.ctxsym
    	env.ctxsym = subtype

    	if( cExpression( expr ) = FALSE ) then
    		hReportError( FB_ERRMSG_EXPECTEDCONST )
    		exit function
    	end if

    	env.ctxsym = oldsym

    	dtype = astGetDataType( expr )
    	if( dtype = FB_DATATYPE_USERDEF ) then
    		if( atype <> FB_DATATYPE_USERDEF ) then
				hReportError( FB_ERRMSG_INVALIDDATATYPES )
				exit function
			end if


    	'' not a constant?
    	elseif( astIsCONST( expr ) = FALSE ) then
    		'' not a literal string?
    		if( (astIsVAR( expr ) = FALSE) or _
    			(dtype <> FB_DATATYPE_CHAR) ) then
				hReportError( FB_ERRMSG_EXPECTEDCONST )
				exit function
			end if

			sym = astGetSymbol( expr )
			'' diff types or isn't it a literal string?
			if( (dclass <> FB_DATACLASS_STRING) or _
				(symbGetIsLiteral( sym ) = FALSE) ) then
				hReportError( FB_ERRMSG_INVALIDDATATYPES )
				exit function
			end if

		else
			'' diff types?
			if( dclass = FB_DATACLASS_STRING ) then
				hReportError( FB_ERRMSG_INVALIDDATATYPES )
				exit function
			end if
		end if

    	optional = TRUE
    	'' string?
    	select case as const atype
    	case FB_DATATYPE_STRING, FB_DATATYPE_FIXSTR, _
    		 FB_DATATYPE_CHAR, FB_DATATYPE_WCHAR
    		optval.str = sym
    	case else
    		astConvertValue( expr, @optval, atype )
    	end select

    	astDel( expr )

    else
    	optional = FALSE
    end if

    if( isproto ) then
    	pid = NULL
    end if

    function = symbAddProcArg( proc, pid, _
    					       atype, subtype, ptrcnt, _
    					   	   alen, amode, asuffix, _
    					   	   optional, @optval )

end function

