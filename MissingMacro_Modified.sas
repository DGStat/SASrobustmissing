
**********************************************************************;
* MISSFIX Macro *;
* *;
* Purpose: To create numeric variables from character variables so *;
* determined during import from an external file due to the *;
* file due to the presence of non-numeric missing values. *;
* *;
* Authors: Hunter Glanz and Josh Horstman *;
* Date : August 12, 2018 *;
* *;
**********************************************************************;
libname macware "G:\My Documents\Biostatistics\SAS Macros\Master Library";
options mstored sasmstore=macware;

%macro missfix(
dsetin = /* Name of input dataset */
,dsetout = /* Name of output dataset */
,missval = /* String to treat as missing (case insensitive) */
)/store source;
/* Determine whether DSETIN parameter includes a library name. */
%IF %INDEX(&dsetin,.) %THEN %DO;
%LET mylib = %SCAN(&dsetin,1,.);
%LET myds = %SCAN(&dsetin,2,.);
%END;
%ELSE %DO;
%LET mylib = WORK;
%LET myds = &dsetin;
%END;
/* Get count and list of character variables. */
proc sql noprint;
select count(*),
 name,
 "new"||name into :varcnt trimmed,
 :varlst separated by ' ', :newvarlst separated by ' '
from dictionary.columns
where memname="%UPCASE(&myds)"
 and libname="%UPCASE(&mylib)" and type="char"
 and upcase(name) not like '%DATE%' ;
quit;
/* Create a new temporary dataset by attempting to convert character
 variables to numeric after removing missing value flags. */
data _tmpfixed;
set &dsetin end=eof;
length dropvarlst $32767 renamelst $32767;
/* Vars array will keep variables which were originally
 character. Newvars array will contain numeric variables that
 were character only due to non-numeric missing value flags. */
array vars (&varcnt) $ &varlst;
array newvars (&varcnt) &newvarlst;
/* dropflag will track which variable should be dropped (1 = drop
 the original character var, 2 = drop the new numeric var) */
array dropflag(&varcnt);
retain dropflag:;
/* Loop through character variables to identify numeric values
 and set flag accordingly. However, once decision has been made
 to drop new numeric variable and keep original character
 variable, subsequent records cannot alter this decision. */
do i = 1 to dim(dropflag);
num = input(vars(i),?? best32.);
IsNum = (not missing(num)) or
 strip(vars[i]) in ('','.') or
(.A le num le .Z) or (num eq ._);
if upcase(vars(i)) in %upcase((&missval)) then
call missing(vars[i],newvars[i]);
else do;
dropflag[i] = max(ifn(IsNum,1,2),dropflag[i]);
newvars[i] = num;
end;
end;
/* After all records are processed, create macro variables
 containing names of variables to be dropped and renamed. */
if eof then do;
do i = 1 to dim(dropflag);
if not missing(dropflag[i]) then
dropvarlst = catx(' ',
 dropvarlst,
choosec(dropflag[i],
 vname(vars[i]),
vname(newvars[i])));
if dropflag[i]=1 then
renamelst = catx(' ',
 renamelst,
catx('=',
 vname(newvars[i]),
vname(vars[i])));
end;
call symputx('dropvarlst', dropvarlst);
call symputx('renamelst', renamelst);
end;
drop dropvarlst renamelst dropflag: i num IsNum;
run;
/* Create the output data set by dropping and renaming
 variables as determined in the previous step. */
data &dsetout;
set _tmpfixed;
%IF %bquote(&dropvarlst) ne %THEN drop &dropvarlst;;
%IF %bquote(&renamelst) ne %THEN rename &renamelst;;
run;
/* Clean up by deleting the temporary data set. */
proc delete data=_tmpfixed; run;
%mend missfix;



/*%missfix_v2(dsetin=work.alldata_v2,dsetout=work.alldata_v3,missval=%str("unknown","na","n/a","#N/A"));*/


/*%missfix_v2(dsetin=salaries_v1,dsetout=salaries_v2,missval=%str("unknown","na","n/a","#N/A","not provided"));*/

