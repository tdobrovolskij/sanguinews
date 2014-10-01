//////////////////////////////////////////////////////////////////////////
// Yencoded - C code to yencode bindary data for sanguinews
// Copyright (c) 2013-2014, Tadeus Dobrovolskij
// This library is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this library; if not, write to the Free Software Foundation, Inc.,
// 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
/////////////////////////////////////////////////////////////////////////
#include <ruby.h>
#include <yencoded.h>

void Init_yencoded() {
  Yencoded = rb_define_module("Yencoded");
  YencodedData = rb_define_module_under(Yencoded, "Data");
  rb_define_singleton_method(YencodedData, "yenc", method_yencoded_data_yenc, 2);
}

VALUE method_yencoded_data_yenc(VALUE self, VALUE data,VALUE length) {
  char *bindata;
  long datalen;
  int i=0;
  int linelen=128;
  long restlen;
  long destlen;
  unsigned char c;
  unsigned char *output;
  unsigned char *start;
  VALUE result;

  // convert ruby variables to c variables
  bindata = StringValuePtr(data);
  datalen = FIX2LONG(length);

  restlen = datalen;                    //restlen is our byte processing counter
  destlen = restlen;                    //will be needing this for memory allocation
  output = (unsigned char*)malloc(2 * destlen * sizeof(char));
  start = output;			    //starting address will be stored here
  while (restlen>0) {
    c=(unsigned char) *bindata;                         //get byte
    c=c+42;           //add 42 as per yenc specs
    bindata++; restlen--;
    switch(c) {                         //special characters
      case 0:
      case 10:
      case 13:
      case 61:
	destlen++; i++;          //we need more memory than expected
	*output=61; output++;    //add escape char to output
	c = c+64;
	break;
      case 9:			   //escape tab and space if the are first or last on the line
      case 32:
	if ((i==0)||(i==linelen-1)) {
	  destlen++; i++;        //we need more memory than expected
          *output=61; output++;  //add escape char to output
          c = c+64;
        }
	break;
      case 46:			   //escape dot if it's in a first column
        if (i==0) {
          destlen++; i++;        //we need more memory than expected
          *output=61; output++;  //add escape char to output
          c = c+64;
        }
	break;
    }
    *output=c; output++; i++;
    if ((i>=linelen)||(restlen==0)){
      destlen++; destlen++;
      *output=13; output++;		   //according to yenc specs we must use windows style line breaks
      *output=10; output++;
      i=0;
    }
  }
  *output=0;			   //NULL termination is required
  destlen++;
  result=rb_str_new2((char*)start);
  free(start);
  return result; 
}
