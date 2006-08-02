SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetPeptideIdentificationMethods]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetPeptideIdentificationMethods]
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
**		Auth: grk
**		Date: 4/7/2004
**    
*****************************************************/
	@message varchar(512) = '' output
As
	set nocount on

	declare @myError int
	set @myError = 0

	declare @myRowCount int
	set @myRowCount = 0
	
	set @message = ''

SELECT     [Name], Internal_Code as Code
FROM         T_Match_Methods
	---------------------------------------------------
	-- Exit
	---------------------------------------------------

Done:
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetPeptideIdentificationMethods]  TO [DMS_SP_User]
GO

