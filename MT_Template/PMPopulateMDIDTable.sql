/****** Object:  StoredProcedure [dbo].[PMPopulateMDIDTable] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.PMPopulateMDIDTable
/****************************************************
**
**	Desc: 
**		Populates table #Tmp_MDIDList with the MDID values in @MDIDs
**		The calling procedure must create this table
**
**	Return values: 0 if no error; otherwise error code
**
**	Auth:	mem
**	Date:	07/16/2009 mem - Initial version
**			08/26/2009 mem - Now using SELECT DISTINCT when populating #Tmp_MDIDList
**			02/15/2011 mem - Now populating Match_Score_Mode in #Tmp_MDIDList
**    
*****************************************************/
(
	@MDIDs varchar(max) = '',
	@message varchar(512)='' output
)
AS
	set nocount on

	Declare @myRowCount int
	Declare @myError int
	set @myRowCount = 0
	set @myError = 0
	
	-------------------------------------------------	
	-- Populate #Tmp_MDIDList
	-------------------------------------------------
	
	INSERT INTO #Tmp_MDIDList (MD_ID, Match_Score_Mode)
	SELECT DISTINCT Value, 0
	FROM dbo.udfParseDelimitedIntegerList(@MDIDs, ',')
	--
	Select @myError = @@Error, @myRowCount = @@RowCount
	
	If @myError <> 0
	Begin
		Set @message = 'Error parsing the MDID list'
		Goto Done
	End
	
	-- Delete invalid entries from #Tmp_MDIDList
	DELETE #Tmp_MDIDList
	FROM #Tmp_MDIDList L
	     LEFT OUTER JOIN T_Match_Making_Description MMD
	       ON L.MD_ID = MMD.MD_ID
	WHERE MMD.MD_ID IS NULL
	--
	Select @myError = @@Error, @myRowCount = @@RowCount
	
	If @myRowCount > 0
	Begin
		Set @message = 'Deleted invalid entries from the MDID List; entry count removed: ' + Convert(varchar(12), @myRowCount)
		Print @message
	End

	
Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[PMPopulateMDIDTable] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[PMPopulateMDIDTable] TO [MTS_DB_Lite] AS [dbo]
GO
