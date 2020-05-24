/*
**  apache.prg -- Apache harbour module
**
** (c) FiveTech Software SL, 2019-2020
** Developed by Antonio Linares alinares@fivetechsoft.com
** MIT license https://github.com/FiveTechSoft/mod_harbour/blob/master/LICENSE
*/

#include "hbclass.ch"
#include "hbhrb.ch"

#xcommand ? [<explist,...>] => AP_RPuts( '<br>' [,<explist>] )

#define CRLF hb_OsNewLine()

#define __HBEXTERN__HBHPDF__REQUEST
#include "../../harbour/contrib/hbhpdf/hbhpdf.hbx"
#define __HBEXTERN__XHB__REQUEST
#include "../../harbour/contrib/xhb/xhb.hbx"
#define __HBEXTERN__HBCT__REQUEST
#include "../../harbour/contrib/hbct/hbct.hbx"
#define __HBEXTERN__HBCURL__REQUEST  
#include "../../harbour/contrib/hbcurl/hbcurl.hbx"
#define __HBEXTERN__HBNETIO__REQUEST
#include "../../harbour/contrib/hbnetio/hbnetio.hbx"
#define __HBEXTERN__HBMZIP__REQUEST
#include "../../harbour/contrib/hbmzip/hbmzip.hbx"
#define __HBEXTERN__HBZIPARC__REQUEST
#include "../../harbour/contrib/hbziparc/hbziparc.hbx"
#define __HBEXTERN__HBSSL__REQUEST
#include "../../harbour/contrib/hbssl/hbssl.hbx"

#ifdef HB_WITH_ADS
   #define __HBEXTERN__RDDADS__REQUEST
   #include "../../harbour/contrib/rddads/rddads.hbx"
#endif

static hPP

//----------------------------------------------------------------//

function Main()

   local cFileName, pThread

   ErrorBlock( { | o | DoBreak( o ) } )

   cFileName = AP_FileName()
   AddPPRules()

   if File( cFileName )
      hb_SetEnv( "PRGPATH",;
                 SubStr( cFileName, 1, RAt( "/", cFileName ) + RAt( "\", cFileName ) - 1 ) )
      if Lower( Right( cFileName, 4 ) ) == ".hrb"
         pThread = hb_threadStart( @ExecuteHrb(), hb_HrbLoad( 1, cFileName ), AP_Args() )
      else
         pThread = hb_threadStart( @Execute(), MemoRead( cFileName ), AP_Args() )
      endif
      if hb_threadWait( pThread, Max( Val( AP_GetEnv( "MHTIMEOUT" ) ), 15 ) ) != 1
         hb_threadQuitRequest( pThread )
	      ErrorLevel( 408 ) // request timeout
      endif    
      InKey( 0.1 )
   else
      ErrorLevel( 404 ) // not found
   endif   

return nil

//----------------------------------------------------------------//

function AddPPRules()

   if hPP == nil
      hPP = __pp_init()
      __pp_path( hPP, "~/harbour/include" )
      __pp_path( hPP, "c:\harbour\include" )
      if ! Empty( hb_GetEnv( "HB_INCLUDE" ) )
         __pp_path( hPP, hb_GetEnv( "HB_INCLUDE" ) )
      endif 	 
   endif

   __pp_addRule( hPP, "#xcommand ? [<explist,...>] => AP_RPuts( '<br>' [,<explist>] )" )
   __pp_addRule( hPP, "#xcommand ?? [<explist,...>] => AP_RPuts( [<explist>] )" )
   __pp_addRule( hPP, "#define CRLF hb_OsNewLine()" )
   __pp_addRule( hPP, "#xcommand TEXT <into:TO,INTO> <v> => #pragma __cstream|<v>:=%s" )
   __pp_addRule( hPP, "#xcommand TEXT <into:TO,INTO> <v> ADDITIVE => #pragma __cstream|<v>+=%s" )
   __pp_addRule( hPP, "#xcommand TEMPLATE [ USING <x> ] [ PARAMS [<v1>] [,<vn>] ] => " + ;
                      '#pragma __cstream | AP_RPuts( InlinePrg( %s, [@<x>] [,<(v1)>][+","+<(vn)>] [, @<v1>][, @<vn>] ) )' )
   __pp_addRule( hPP, "#xcommand BLOCKS [ PARAMS [<v1>] [,<vn>] ] => " + ;
                      '#pragma __cstream | AP_RPuts( ReplaceBlocks( %s, "{{", "}}" [,<(v1)>][+","+<(vn)>] [, @<v1>][, @<vn>] ) )' )   
   __pp_addRule( hPP, "#command ENDTEMPLATE => #pragma __endtext" )
   __pp_addRule( hPP, "#xcommand TRY  => BEGIN SEQUENCE WITH {| oErr | Break( oErr ) }" )
   __pp_addRule( hPP, "#xcommand CATCH [<!oErr!>] => RECOVER [USING <oErr>] <-oErr->" )
   __pp_addRule( hPP, "#xcommand FINALLY => ALWAYS" )
   __pp_addRule( hPP, "#xcommand DEFAULT <v1> TO <x1> [, <vn> TO <xn> ] => ;" + ;
                      "IF <v1> == NIL ; <v1> := <x1> ; END [; IF <vn> == NIL ; <vn> := <xn> ; END ]" )
		      
return nil

//----------------------------------------------------------------//

function ExecuteHrb( oHrb, cArgs )

   ErrorBlock( { | oError | AP_RPuts( GetErrorInfo( oError ) ), Break( oError ) } )

return hb_HrbDo( oHrb, cArgs )

//----------------------------------------------------------------//

function Execute( cCode, ... )

   local oHrb, uRet, lReplaced := .T.
   local cHBheaders1 := "~/harbour/include"
   local cHBheaders2 := "c:\harbour\include"

   ErrorBlock( { | oError | AP_RPuts( GetErrorInfo( oError, @cCode ) ), Break( oError ) } )

   while lReplaced 
      lReplaced = ReplaceBlocks( @cCode, "{%", "%}" )
      cCode = __pp_process( hPP, cCode )
   end

   oHrb = HB_CompileFromBuf( cCode, .T., "-n", "-I" + cHBheaders1, "-I" + cHBheaders2,;
                             "-I" + hb_GetEnv( "HB_INCLUDE" ), hb_GetEnv( "HB_USER_PRGFLAGS" ) )
   if ! Empty( oHrb )
      uRet = hb_HrbDo( hb_HrbLoad( 1, oHrb ), ... )
   endif

return uRet

//----------------------------------------------------------------//

function GetErrorInfo( oError, cCode )

   local n, cInfo := "Error: " + oError:description + "<br>"
   local aLines, nLine

   if ! Empty( oError:operation )
      cInfo += "operation: " + oError:operation + "<br>"
   endif   

   if ! Empty( oError:filename )
      cInfo += "filename: " + oError:filename + "<br>"
   endif   
   
   if ValType( oError:Args ) == "A"
      for n = 1 to Len( oError:Args )
          cInfo += "[" + Str( n, 4 ) + "] = " + ValType( oError:Args[ n ] ) + ;
                   "   " + ValToChar( oError:Args[ n ] ) + ;
                   If( ValType( oError:Args[ n ] ) == "A", " Len: " + ;
                   AllTrim( Str( Len( oError:Args[ n ] ) ) ), "" ) + "<br>"
      next
   endif	
	
   n = 2
   while ! Empty( ProcName( n ) )  
      cInfo += "called from: " + If( ! Empty( ProcFile( n ) ), ProcFile( n ) + ", ", "" ) + ;
               ProcName( n ) + ", line: " + ;
               AllTrim( Str( ProcLine( n ) ) ) + "<br>"
      n++
   end

   if ! Empty( cCode )
      aLines = hb_ATokens( cCode, Chr( 10 ) )
      cInfo += "<br>Source:<br>" + CRLF
      n = 1
      while( nLine := ProcLine( ++n ) ) == 0
      end   
      for n = Max( nLine - 2, 1 ) to Min( nLine + 2, Len( aLines ) )
         cInfo += StrZero( n, 4 ) + If( n == nLine, " =>", ": " ) + ;
                  hb_HtmlEncode( aLines[ n ] ) + "<br>" + CRLF
      next
   endif      

return cInfo

//----------------------------------------------------------------//

static procedure DoBreak( oError )

   ? GetErrorInfo( oError )

   BREAK

//----------------------------------------------------------------//

function LoadHRB( cHrbFile_or_oHRB )

   local lResult := .F.

   if ValType( cHrbFile_or_oHRB ) == "C"
      if File( hb_GetEnv( "PRGPATH" ) + "/" + cHrbFile_or_oHRB )
         AAdd( M->getList,;
            hb_HrbLoad( 1, hb_GetEnv( "PRGPATH" ) + "/" + cHrbFile_or_oHRB ) )
         lResult = .T.   
      endif      
   endif
   
   if ValType( cHrbFile_or_oHRB ) == "P"
      AAdd( M->getList, hb_HrbLoad( 1, cHrbFile_or_oHRB ) )
      lResult = .T.
   endif
   
return lResult   

//----------------------------------------------------------------//

function ObjToChar( o )

   local hObj := {=>}, aDatas := __objGetMsgList( o, .T. )
   local hPairs := {=>}, aParents := __ClsGetAncestors( o:ClassH )

   AEval( aParents, { | h, n | aParents[ n ] := __ClassName( h ) } ) 

   hObj[ "CLASS" ] = o:ClassName()
   hObj[ "FROM" ]  = aParents 

   AEval( aDatas, { | cData | hPairs[ cData ] := __ObjSendMsg( o, cData ) } )
   hObj[ "DATAs" ]   = hPairs
   hObj[ "METHODs" ] = __objGetMsgList( o, .F. )

return ValToChar( hObj )

//----------------------------------------------------------------//

function ValToChar( u )

   local cType := ValType( u )
   local cResult

   do case
      case cType == "C" .or. cType == "M"
           cResult = u

      case cType == "D"
           cResult = DToC( u )

      case cType == "L"
           cResult = If( u, ".T.", ".F." )

      case cType == "N"
           cResult = AllTrim( Str( u ) )

      case cType == "A"
           cResult = hb_ValToExp( u )

      case cType == "O"
           cResult = ObjToChar( u )

      case cType == "P"
           cResult = "(P)" 

      case cType == "S"
           cResult = "(Symbol)" 
 
      case cType == "H"
           cResult = StrTran( StrTran( hb_JsonEncode( u, .T. ), CRLF, "<br>" ), " ", "&nbsp;" )
           if Left( cResult, 2 ) == "{}"
              cResult = StrTran( cResult, "{}", "{=>}" )
           endif   

      case cType == "U"
           cResult = "nil"

      otherwise
           cResult = "type not supported yet in function ValToChar()"
   endcase

return cResult   

//----------------------------------------------------------------//

function InlinePRG( cText, oTemplate, cParams, ... )

   local nStart, nEnd, cCode, cResult

   if PCount() > 1
      oTemplate = Template()
      if PCount() > 2
         oTemplate:cParams = cParams
      endif   
   endif   

   while ( nStart := At( "<?prg", cText ) ) != 0
      nEnd  = At( "?>", SubStr( cText, nStart + 5 ) )
      cCode = SubStr( cText, nStart + 5, nEnd - 1 )
      if oTemplate != nil
         AAdd( oTemplate:aSections, cCode )
      endif   
      cText = SubStr( cText, 1, nStart - 1 ) + ( cResult := ExecInline( cCode, cParams, ... ) ) + ;
              SubStr( cText, nStart + nEnd + 6 )
      if oTemplate != nil
         AAdd( oTemplate:aResults, cResult )
      endif   
   end 
   
   if oTemplate != nil
      oTemplate:cResult = cText
   endif   
   
return cText

//----------------------------------------------------------------//

function ExecInline( cCode, cParams, ... )

   if cParams == nil
      cParams = ""
   endif   

return Execute( "function __Inline( " + cParams + " )" + HB_OsNewLine() + cCode, ... )   

//----------------------------------------------------------------//

CLASS Template

   DATA aSections INIT {}
   DATA aResults  INIT {}
   DATA cParams   
   DATA cResult

ENDCLASS

//----------------------------------------------------------------//

function ReplaceBlocks( cCode, cStartBlock, cEndBlock, cParams, ... )

   local nStart, nEnd, cBlock
   local lReplaced := .F.
   
   hb_default( @cStartBlock, "{{" )
   hb_default( @cEndBlock, "}}" )
   hb_default( @cParams, "" )

   while ( nStart := At( cStartBlock, cCode ) ) != 0 .and. ;
         ( nEnd := At( cEndBlock, cCode ) ) != 0
      cBlock = SubStr( cCode, nStart + Len( cStartBlock ), nEnd - nStart - Len( cEndBlock ) )
      cCode = SubStr( cCode, 1, nStart - 1 ) + ;
              ValToChar( Eval( &( "{ |" + cParams + "| " + cBlock + " }" ), ... ) ) + ;
      SubStr( cCode, nEnd + Len( cEndBlock ) )
          lReplaced = .T.
   end
   
return If( HB_PIsByRef( 1 ), lReplaced, cCode )

//----------------------------------------------------------------//

function PathUrl()

   local cPath := AP_GetEnv( 'SCRIPT_NAME' )   
   local n     := RAt( '/', cPath )
        
return Substr( cPath, 1, n - 1 )

//----------------------------------------------------------------//

function PathBase( cDirFile )

   local cPath := hb_GetEnv( "PRGPATH" ) 
    
   hb_default( @cDirFile, '' )
    
   cPath += cDirFile
    
   if "Linux" $ OS()    
      cPath = StrTran( cPath, '\', '/' )     
   endif
   
return cPath

//----------------------------------------------------------------//

function Include( cFile )

   local cPath := AP_GetEnv( "DOCUMENT_ROOT" ) 

   hb_default( @cFile, '' )
   cFile = cPath + cFile   
   
   if "Linux" $ OS()
      cFile = StrTran( cFile, '\', '/' )     
   endif   
    
   if File( cFile )
      return MemoRead( cFile )
   endif
   
return ""

//----------------------------------------------------------------//

function GetCookies()

   local cCookies := AP_GetEnv( "HTTP_COOKIE" )
   local aCookies := hb_aTokens( cCookies, ";" )
   local cCookie, hCookies := {=>}
   local hHeadersOut := AP_HeadersOut(), cCookieHeader

   if( hb_HHasKey( hHeadersOut, "Set-Cookie" ) )
      cCookieHeader := hHeadersOut[ "Set-Cookie" ]
      cCookieHeader := Left( cCookieHeader, At( ';', cCookieHeader )-1 )
      AAdd( aCookies, cCookieHeader )
   endif
   
   for each cCookie in aCookies
      hb_HSet( hCookies, LTrim( SubStr( cCookie, 1, At( "=", cCookie ) - 1 ) ),;
               SubStr( cCookie, At( "=", cCookie ) + 1 ) )
   next   
   
 return hCookies

//----------------------------------------------------------------//

function SetCookie( cName, cValue, nSecs, cPath, cDomain, lHttps, lOnlyHttp ) 

   local cCookie := ''
	
   // check parameters
   hb_default( @cName, '' )
   hb_default( @cValue, '' )
   hb_default( @nSecs, 3600 )   // Session will expire in Seconds 60 * 60 = 3600
   hb_default( @cPath, '/' )
   hb_default( @cDomain	, '' )
   hb_default( @lHttps, .F. )
   hb_default( @lOnlyHttp, .F. )	
	
   // we build the cookie
   cCookie += cName + '=' + cValue + ';'
   cCookie += 'expires=' + CookieExpire( nSecs ) + ';'
   cCookie += 'path=' + cPath + ';'
   
   if ! Empty( cDomain )
      cCookie += 'domain=' + cDomain + ';'
   endif
		
   // pending logical values for https y OnlyHttp

   // we send the cookie
   AP_HeadersOutSet( "Set-Cookie", cCookie )

return nil

//----------------------------------------------------------------//
// CookieExpire( nSecs ) builds the time format for the cookie
// Using this model: 'Sun, 09 Jun 2019 16:14:00'

function CookieExpire( nSecs )

   local tNow := hb_datetime()	
   local tExpire   // TimeStampp 
   local cExpire   // TimeStamp to String
	
   hb_default( @nSecs, 60 ) // 60 seconds for this test
   
   tExpire = hb_ntot( ( hb_tton( tNow ) * 86400 - hb_utcoffset() + nSecs ) / 86400 )

   cExpire = cdow( tExpire ) + ', ' 
	     cExpire += AllTrim( Str( Day( hb_TtoD( tExpire ) ) ) ) + ;
	     ' ' + cMonth( tExpire ) + ' ' + AllTrim( Str( Year( hb_TtoD( tExpire ) ) ) ) + ' ' 
   cExpire += AllTrim( Str( hb_Hour( tExpire ) ) ) + ':' + AllTrim( Str( hb_Minute( tExpire ) ) ) + ;
              ':' + AllTrim( Str( hb_Sec( tExpire ) ) )

return cExpire

//----------------------------------------------------------------//

function hb_HtmlEncode( cString )
   
   local cChar, cResult := "" 

   for each cChar in cString
      do case
      case cChar == "<"
            cChar = "&lt;"

      case cChar == '>'
            cChar = "&gt;"     
            
      case cChar == "&"
            cChar = "&amp;"     

      case cChar == '"'
            cChar = "&quot;"    
            
      case cChar == " "
            cChar = "&nbsp;"               
      endcase
      cResult += cChar 
   next
    
return cResult   

//----------------------------------------------------------------//

#pragma BEGINDUMP

#include <hbapi.h>
#include <hbvm.h>
#include <hbapierr.h>

static void * pRequestRec;

#ifdef _MSC_VER
   #pragma warning(disable:4996)
   #include <windows.h>

HB_FUNC( SHOWCONSOLE )     // to use the debugger locally on Windows
{
   ShowWindow( GetConsoleWindow(),  3 );
   ShowWindow( GetConsoleWindow(), 10 );
}

#else

HB_FUNC( SHOWCONSOLE )
{
}

#endif

HB_EXPORT_ATTR int hb_apache( void * _pRequestRec )
{
   pRequestRec = _pRequestRec;
 
   hb_vmInit( HB_TRUE );
   return hb_vmQuit();
}   

void * GetRequestRec( void )
{
   return pRequestRec;
}

HB_FUNC( PTRTOSTR )
{
   #ifdef HB_ARCH_32BIT
      const char * * pStrs = ( const char * * ) hb_parnl( 1 );   
   #else
      const char * * pStrs = ( const char * * ) hb_parnll( 1 );   
   #endif

   hb_retc( * ( pStrs + hb_parnl( 2 ) ) );
}

HB_FUNC( PTRTOUI )
{
   #ifdef HB_ARCH_32BIT
      unsigned int * pNums = ( unsigned int * ) hb_parnl( 1 );   
   #else
      unsigned int * pNums = ( unsigned int * ) hb_parnll( 1 );   
   #endif

   hb_retnl( * ( pNums + hb_parnl( 2 ) ) );
}

HB_FUNC( HB_URLDECODE ) // Giancarlo's TIP_URLDECODE
{
   const char * pszData = hb_parc( 1 );

   if( pszData )
   {
      HB_ISIZ nLen = hb_parclen( 1 );

      if( nLen )
      {
         HB_ISIZ nPos = 0, nPosRet = 0;

         /* maximum possible length */
         char * pszRet = ( char * ) hb_xgrab( nLen );

         while( nPos < nLen )
         {
            char cElem = pszData[ nPos ];

            if( cElem == '%' && HB_ISXDIGIT( pszData[ nPos + 1 ] ) &&
                                HB_ISXDIGIT( pszData[ nPos + 2 ] ) )
            {
               cElem = pszData[ ++nPos ];
               pszRet[ nPosRet ]  = cElem - ( cElem >= 'a' ? 'a' - 10 :
                                            ( cElem >= 'A' ? 'A' - 10 : '0' ) );
               pszRet[ nPosRet ] <<= 4;
               cElem = pszData[ ++nPos ];
               pszRet[ nPosRet ] |= cElem - ( cElem >= 'a' ? 'a' - 10 :
                                            ( cElem >= 'A' ? 'A' - 10 : '0' ) );
            }
            else
               pszRet[ nPosRet ] = cElem == '+' ? ' ' : cElem;

            nPos++;
            nPosRet++;
         }

         /* this function also adds a zero */
         /* hopefully reduce the size of pszRet */
         hb_retclen_buffer( ( char * ) hb_xrealloc( pszRet, nPosRet + 1 ), nPosRet );
      }
      else
         hb_retc_null();
   }
   else
      hb_errRT_BASE( EG_ARG, 3012, NULL,
                     HB_ERR_FUNCNAME, 1, hb_paramError( 1 ) );
}


#pragma ENDDUMP