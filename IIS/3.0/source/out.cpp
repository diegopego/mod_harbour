#define WIN32_LEAN_AND_MEAN
#include "httpserv.h"
#include <hbapi.h>

extern "C" {

IHttpContext * GetHttpContext( void );

HB_FUNC( AP_RPUTS )
{
   const char * szText = hb_parc( 1 );
   HTTP_DATA_CHUNK dataChunk;
   IHttpContext * pHttpContext = GetHttpContext();
   PCSTR pszText = ( PCSTR ) pHttpContext->AllocateRequestMemory( strlen( szText ) + 1 );
   IHttpResponse * pHttpResponse = pHttpContext->GetResponse();

   if( pszText )
   {
      strcpy( ( char * ) pszText, szText );

      dataChunk.DataChunkType = HttpDataChunkFromMemory;
      dataChunk.FromMemory.pBuffer = ( PVOID ) pszText;
      dataChunk.FromMemory.BufferLength = ( ULONG ) strlen( pszText );

      hb_retnl( pHttpResponse->WriteEntityChunkByReference( &dataChunk, -1 ) );
   }
   else
      hb_retnl( 0 );
}

HB_FUNC( AP_SETCONTENTTYPE )
{
   IHttpContext * pHttpContext = GetHttpContext();
   IHttpResponse * pHttpResponse = pHttpContext->GetResponse();

   pHttpResponse->SetHeader( "Content-Type", hb_parc( 1 ), hb_parclen( 1 ), true );
}

HB_FUNC( AP_HEADERSOUTCOUNT )
{
   IHttpContext * pHttpContext = GetHttpContext();
   IHttpResponse * pHttpResponse = pHttpContext->GetResponse();

   hb_retnl( pHttpResponse->GetRawHttpResponse()->Headers.UnknownHeaderCount );
}

}