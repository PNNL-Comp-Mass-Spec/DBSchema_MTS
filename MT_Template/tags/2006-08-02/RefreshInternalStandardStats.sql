SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[RefreshInternalStandardStats]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[RefreshInternalStandardStats]
GO


CREATE Procedure dbo.RefreshInternalStandardStats
/****************************************************
**
**	Desc: 
**		Updates peptide and protein information for the peptides in
**		T_Mass_Tags that correspond to internal standard components in MT_Main
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	12/15/2005
**    
*****************************************************/
(
 	@message varchar(255) = '' output
 )
As
	set nocount on

	declare @myError int
	declare @myRowCount int
	set @myError = 0
	set @myRowCount = 0

	set @message = ''
	
	Declare @MassTagID int
	Declare @Continue tinyint
	
	---------------------------------------------------	
	-- Create a temporary table to hold the list of Seq_ID values to update
	---------------------------------------------------	
	--
	CREATE TABLE #TmpSeqsToUpdate (
		Mass_Tag_ID int
	)

	CREATE CLUSTERED INDEX #IX_TmpSeqsToUpdate ON #TmpSeqsToUpdate (Mass_Tag_ID ASC)


	---------------------------------------------------	
	-- Populate #TmpSeqsToUpdate
	---------------------------------------------------	
	--
	INSERT INTO #TmpSeqsToUpdate (Mass_Tag_ID)
	SELECT DISTINCT MT.Mass_Tag_ID
	FROM T_Mass_Tags MT INNER JOIN
		 MT_Main.dbo.T_Internal_Std_Components ISC ON 
		 MT.Mass_Tag_ID = ISC.Seq_ID
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	
	Set @MassTagID = 0
	SELECT @MassTagID = MIN(Mass_Tag_ID)-1
	FROM #TmpSeqsToUpdate
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	---------------------------------------------------	
	-- Loop through #TmpSeqsToUpdate processing each entry
	---------------------------------------------------	
	--
	Set @Continue = 1
	While @Continue = 1 and @myError = 0
	Begin
		-- Grab the next entry
		SELECT TOP 1 @MassTagID = Mass_Tag_ID
		FROM #TmpSeqsToUpdate
		WHERE Mass_Tag_ID > @MassTagID
		ORDER BY Mass_Tag_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	
		If @myRowCount = 0 or @myError <> 0
			Set @Continue = 0
		Else
		Begin
			exec @myError = AddUpdateInternalStandardEntry @MassTagID, @PostLogEntry = 1
		End
	End

Done:
	return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

