########################################################################
# Yencoded - inline C code to yencode bindary data for sanguinews
# Copyright (c) 2013, Tadeus Dobrovolskij
# This library is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this library; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
########################################################################

require 'inline'

class Yencoded
  inline do |builder|
    builder.c "
    char *yenc(char *bindata,long datalen) {
      int i=0;
      int linelen=128;
      long restlen;
      long destlen;
      long pointer;
      unsigned char c;
      unsigned char *output;
      unsigned char *start;

      restlen = datalen;                    //restlen is our byte processing counter
      destlen = restlen;                    //will be needing this for memory allocation
      pointer = 0;
      output = malloc(destlen * sizeof(char));
      start = output;
      while (restlen>0) {
        c=*bindata;                         //get byte
        c=(unsigned char) (c+42);           //add 42 as per yenc specs
        bindata++; restlen--;
        switch(c) {                         //special characters
          case 0:
          case 10:
          case 13:
          case '=':
                  destlen++; i++;           //we need more memory than expected
                  start = realloc(start,destlen * sizeof(char));
                  output = &start[pointer]; //in case realloc was in different memspace
                  *output='='; output++;    //add escape char to output
                  c = (unsigned char) (c+64);
                  pointer++;
        }
        *output=c; output++; i++;
        pointer++;
        if ((i>=linelen)|(restlen==0)){
          destlen++;
          start = realloc(start,destlen * sizeof(char));
          output = &start[pointer];         //in case realloc was in different memspace
          *output=10; output++;
          pointer++; 
          i=0;
        }
      }
      return start;
    }"
  end
end
