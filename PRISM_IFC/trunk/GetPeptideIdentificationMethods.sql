/****** Object:  StoredProcedure [dbo].[GetPeptideIdentificationMethods] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.GetPeptideIdentificationMethods
/****************************************************
**
**	Desc: 
**		Return list of all identification
**		methods for matching peaks to peptides
**   
**  Results set contains columns:
**     Name  -- User-meaningful public name for method (may change)
**     Code  -- Internal code for method (won't change)    
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**		@message  -- explanation of any error that occurred
**
**	Auth:	grk
**	Date:	04/07/2004
**			04/06/2006 mem - Now sorting the identification methods on column Match_Method_ID
**    
*****************************************************/
(
	@message varchar(512) = '' output
)
As
	set nocount on

	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	set @message = ''

	SELECT [Name], Internal_Code as Code
	FROM T_Match_Methods
	ORDER BY Match_Method_ID

	---------------------------------------------------
	-- Exit
	---------------------------------------------------

Done:
	return @myError

GO
GRANT EXECUTE ON [dbo].[GetPeptideIdentificationMethods] TO [DMS_SP_User]
GO
