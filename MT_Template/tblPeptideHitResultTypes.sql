/****** Object:  UserDefinedFunction [dbo].[tblPeptideHitResultTypes] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

create FUNCTION tblPeptideHitResultTypes
/****************************************************	
**	Returns the standard Peptide_Hit result types
**
**
**	Auth:	mem
**	Date:	12/05/2012 mem - Initial version
**  
****************************************************/
(
)
RETURNS @tmpValues TABLE(ResultType varchar(64))
AS
BEGIN

	INSERT INTO @tmpValues (ResultType)  Values ('Peptide_Hit')
	INSERT INTO @tmpValues (ResultType)  Values ('XT_Peptide_Hit')
	INSERT INTO @tmpValues (ResultType)  Values ('IN_Peptide_Hit')
	INSERT INTO @tmpValues (ResultType)  Values ('MSG_Peptide_Hit')
	INSERT INTO @tmpValues (ResultType)  Values ('MSA_Peptide_Hit')
	
	RETURN
END

GO
