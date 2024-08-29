//This C program decompiles 85s LVL files
//Copyright (c) 2024 by Chris Busch
//Disclaimer: this program might not be fit for purpose
//All risks assumed by one who runs it.

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>


#define BUFSIZE 1024
char buffer[BUFSIZE];

#define MAXSTRS 64
char* strings[MAXSTRS];
int strnum=0;

int maxlevels=255;
int pics=-1;
int levels=-1;
				//0123456789ABCDE
char* mapdef=".PMmcsfFBStbDkW";
				//01234567890123456789012
char* picdef=".PMmcsfFBStbDk.PMmcsfF";
char* picnum="0000000000000011111111";
char* leveldef=".PMmcsfFBStbDkW";
char* scrollsPicNames[]={"blank","Player","patrolling Monster","seeker monster","coin","scroll",
	"fire","bomb","bullet","splat","tree","brick","door","key",
	"blank","Player","patrolling Monster","seeker monster","coin","scroll",
	"fire","bomb","bullet","splat","tree","brick","door","key","OVERRUN"};
char* cavesPicNames[]={"blank","Player","crawling Monster","flying monster","coin","scroll",
	"water or lava","bomb","bullet","stain","shootable brick or block","brick","door","key",
	"blank","Player","crawling Monster","flying monster","coin","scroll",
	"water or lava","bomb","bullet","stain","shootable brick or block","brick","door","key","OVERRUN"};
char** picnames=scrollsPicNames;

int maxpicnames=21;
long lvlandptr=-1;
char* dolT;
int spitX=0;
long extrazone=65535L;
char* comment="";

#define MAXPICLINES 4000
char* picbuffer[MAXPICLINES];
int piclines=0;
char bigstr[256];
int scrolls=0;
int randomTrees=-1;

int main(int argc,char *argv[]) {
	puts("Caves and Scrolls level decompiler."
		  "(c)2024 Chris Busch");
	if(argc!=3) {
		fprintf(stderr,"usage: %s infile.85s outfile.lvl\n"
		"Prints out debug while writing lvl.\n"
		"Results undefined if not lvl 85s file.\n",
			argv[0]);
		return -1;
	}
	FILE *file=fopen(argv[1],"rb");
	if(file==NULL){
		perror("error opening 85s file");
		return -1;
	}
	FILE *ofile=fopen(argv[2],"wb");
	if(ofile==NULL){
		perror("error writing lvl file");
		return -1;
	}
	int counter=0;
	int mode=0; //hex=1, ascii=2
	int c;
	long dataOffset=32000;
	long picOffset=dataOffset;
	long levelOffset=dataOffset;
	buffer[0]=0;
	int bindex=0;
	while((c=fgetc(file))!=EOF){
		if(  c>=32 && c<=126 && counter<=picOffset) {
			//////////   text interpretation /////
			if(mode!=2){
				printf("\n%10d STR:",counter);
				bindex=0;
				buffer[0]=0;
			}
			printf("%c",c);
			if( bindex>=BUFSIZE-3){
				bindex=0;
			}
			buffer[bindex++]=c;
			buffer[bindex]=0;
			mode=2;

			int v10=strstr(buffer,"LVL v1.0      (C)1996")!=NULL;
			int v11=strstr(buffer,"LVLv1.1 cbusch(C)1996")!=NULL;
			int v16=strstr(buffer,"LVL1.6(C)1996 CBusch") !=NULL;
			int v20=strstr(buffer,"LVL v2.0     (C) 1996")!=NULL;
			int v31=strstr(buffer,"LVL v3.1     (C) 1996")!=NULL;
			int v40=strstr(buffer,"LVL4.0(C)1996 CBusch")!=NULL;

			if( v10 || v16 ) {
				lvlandptr=338;
			}
			if( v10 || v11 || v16 || v20 || v31 || v40 ){
				printf("\nFound '%s' at %d",buffer,counter);
				if(strlen(buffer)>21+21+16){
					char* dolS=strdup(buffer);
					char* dolA=strdup(buffer+21);
					char* dolP=strdup(buffer+21+21);
					char* note=buffer+21+21;
					dolS[21]=0; //set terminators
					dolA[21]=0;
					dolP[16]=0;
					fprintf(ofile,"\n;%s\n",note);
					fprintf(ofile,"\n$T=\"%s\"   ;ZShell name\n",dolT);
					printf("\n$S=\"%s\"  ;Story Title\n"
					  "$A=\"%s\"  ;\n"
					  "$P=\"%s\"  ;high score line\n",dolS,dolA,dolP);
					fprintf(ofile,"\n$S=\"%s\"  ;Story Title\n"
					  "$A=\"%s\"  ;\n",dolS,dolA);
					if(v40){
						fprintf(ofile,"$P=\"%s\"  ;high score line\n", dolP);
					}
					if( scrolls ) {
					  if( randomTrees==1 ) {
							fprintf(ofile,"\n-R ;no random trees\n");
					  }else if(randomTrees==0){ //then generate trees
							fprintf(ofile,"\n+R ;random tree growth\n");
					  }
					}

				}
				dataOffset=counter;
				picOffset=counter+2;

				if(v10 || v11 || v16 || v20 || v31 ){
					picOffset++;
				}
				levelOffset=picOffset+176;
			}
		}else{
			/////// binary interpretation
			if(counter == 107+strlen(comment)){
				 printf("\nFinding random trees setting:%d\n",c);
				 if( (c==0 || c==1) )  randomTrees=c;
			}
			if(counter==lvlandptr){
				printf("\n%d ;suspected number of levels\n",c+1);
				fprintf(ofile,"%d ;number of levels\n",c+1);
				maxlevels=c+1;
			}
			if(mode==2 && strlen(buffer)>2 && strnum<MAXSTRS-1){
				if(strstr(buffer,"SENGINE")!=NULL){
					picnames=scrollsPicNames;
					scrolls=1;
					puts("\nScrolls level detected.");
				}else	if(strstr(buffer,"CENGINE")!=NULL){
					picnames=cavesPicNames;
				}
				if(strstr(buffer,"ENGINE")!=NULL){

					fprintf(ofile,";%s\n",buffer);

				}else if(strstr(buffer,"NEEDS")!=NULL){
					fprintf(ofile,";%s\n",buffer);
				}
				strings[strnum]=strdup(buffer);
				printf("\nFOUND: %d '%s'\n",strnum,buffer);
				if(strnum==2) { //file comment line
					fprintf(ofile,"%s\n",strings[strnum]);
					printf("\nFOUND COMMENT:'%s'\n",strings[strnum]);
					comment=strings[strnum];
				}else	if( strnum==3) { //$T variable
					lvlandptr=counter+34-12;
					printf("\n%d Will look for levelandnum at %d\n",counter,
						lvlandptr);
					printf("\n$T=\"%s\";ZShell name\n",strings[strnum]);
					dolT=strings[strnum];
				}
				strnum++;
			}
			if(counter>=levelOffset){
				if((counter-levelOffset)%512==0){
					levels++;
					if(levels<maxlevels){
						printf("\nLEVEL %d\n",levels+1);
						fprintf(ofile,"\n\n;LEVEL %d\n",levels+1);
					}else{
						printf("\nEXTRA %d\n",levels+1);
						extrazone=levels;
					}
					spitX=1;
				}
				if((counter-levelOffset)%16==0){
					printf("\n%10d LVL:",counter);
					fprintf(ofile,"\n");
				}
				//printf("%02X",c);
				int hi=c>>4;
				int lo=c & 0xF;
				if( levels<maxlevels){
					fprintf(ofile,"%c%c",spitX==1 ? 'X' : mapdef[hi],mapdef[lo]);
				}
				printf("%c%c",spitX==1 ? 'X' : mapdef[hi],mapdef[lo]);
				spitX=0;
			}else if(counter>=picOffset){
				//write out picture definition
				if((counter-picOffset)%8==0){
					pics++;
					printf("\n#%c%c  ;%s PIC %d\n",picdef[pics],picnum[pics],
						picnames[pics],
						pics);
					sprintf(bigstr,"\n\n#%c%c  ;%s PIC %d\n",picdef[pics],picnum[pics],
						picnames[pics],
						pics);
					picbuffer[piclines++]=strdup(bigstr);
				}
				printf("%10d BIN:",counter);
				for(int i=7;i>=0;i--){
					printf("%c",((c>>i)& 1)==0? '.' : 'X' );
					sprintf(bigstr,"%c",((c>>i)& 1)==0? '0' : '1' );
					picbuffer[piclines++]=strdup(bigstr);
				}
				sprintf(bigstr," ;");
				picbuffer[piclines++]=strdup(bigstr);
				for( i=7;i>=0;i--){
					sprintf(bigstr,"%c",((c>>i)& 1)==0? ' ' : '#' );
					picbuffer[piclines++]=strdup(bigstr);
				}
				sprintf(bigstr,"\n");
				picbuffer[piclines++]=strdup(bigstr);
				printf("b %02Xh %3dd\n",c,c);
			}else{
				if(mode!=1){
					printf("\n%10d HEX:",counter);
				}
				printf("%02X ",(unsigned char)c);
			}
			mode=1;
		}
		counter++;
	}
	if(extrazone>maxlevels){
		puts("WARNING TOO MUCH DATA NEAR END");
		fprintf(stderr,"WARNING TOO MANY LEVELS %d: %s must be hand repaired.\n",levels,argv[2]);
	}
	printf("\n%10d END!",counter-1);
	for(int i=0;i<piclines;i++){
		fprintf(ofile,"%s",picbuffer[i]);
	}
	fprintf(ofile,"\n;END\n");
	return 0;
}

//EOF