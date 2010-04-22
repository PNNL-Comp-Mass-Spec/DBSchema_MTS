/****** Object:  StoredProcedure [dbo].[ExcludePeptidesByProteinCollection] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ExcludePeptidesByProteinCollection
/****************************************************	
**  Desc: Looks for peptides that only originate from STM proteins
**        Updates PMT_Quality_Score for these peptides to 0
**
**  Return values: 0 if success, otherwise, error code 
**
**  Auth: mem
**	Date: 02/13/2008
**
****************************************************/
(
	@ProteinCollectionID int = 1001,
	@infoOnly tinyint = 0,
	@message varchar(512) = '' output
)
AS 

	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	Set @message = ''
	
	Declare @ProteinCollectionName varchar(128)
		
	SELECT @ProteinCollectionName = [Name]
	FROM MT_Main.dbo.V_DMS_Protein_Collection_List_Import
	WHERE (Protein_Collection_ID = @ProteinCollectionID)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @myRowCount = 0
		Set @ProteinCollectionName = '??_ID' + Convert(varchar(12), @ProteinCollectionID) + '_??'

	CREATE TABLE #TmpMTsToExclude (
		Mass_Tag_ID int
	)
	
	INSERT INTO #TmpMTsToExclude (Mass_Tag_ID)
	SELECT DISTINCT MT.Mass_Tag_ID
	FROM T_Mass_Tags MT
		INNER JOIN T_Mass_Tag_to_Protein_Map MTPM ON MT.Mass_Tag_ID = MTPM.Mass_Tag_ID
		INNER JOIN T_Proteins Prot ON MTPM.Ref_ID = Prot.Ref_ID
	WHERE (MT.PMT_Quality_Score > 0) AND Not Prot.Protein_Collection_ID Is Null
	GROUP BY MT.Mass_Tag_ID, MT.PMT_Quality_Score
	HAVING (MIN(Prot.Protein_Collection_ID) = @ProteinCollectionID) AND
		   (MAX(Prot.Protein_Collection_ID) = @ProteinCollectionID)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	If @InfoOnly = 0
	Begin
		UPDATE T_Mass_Tags
		SET PMT_Quality_Score = 0
		FROM T_Mass_Tags MT
			INNER JOIN #TmpMTsToExclude
			ON MT.Mass_Tag_ID = #TmpMTsToExclude.Mass_Tag_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	End
	
	Set @message = 'Changed PMT Quality Score to 0 for ' + Convert(varchar(12), @myRowCount) + ' peptides that are only present in protein collection ID ' + convert(varchar(12), @ProteinCollectionID) + '(' + @ProteinCollectionName + ')'

	If @InfoOnly <> 0
		SELECT @message as Message
	Else
	Begin
		If @myRowCount > 0 and @InfoOnly = 0
			Exec PostLogEntry 'Normal', @message, 'ExcludePeptidesByProteinCollection'
	End
			
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[ExcludePeptidesByProteinCollection] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[ExcludePeptidesByProteinCollection] TO [MTS_DB_Lite] AS [dbo]
GO
