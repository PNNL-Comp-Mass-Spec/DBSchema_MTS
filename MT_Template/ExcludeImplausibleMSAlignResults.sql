/****** Object:  StoredProcedure [dbo].[ExcludeImplausibleMSAlignResults] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.ExcludeImplausibleMSAlignResults
/****************************************************	
**  Desc:	Excludes any MSAlign results with a mass-only modification 
**			on a residue where the mass is above a threshold (default +/-500 Da)
**
**  Return values: 0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	09/01/2015 mem
**
****************************************************/
(
	@massThreshold float = 500,		-- Mass threshold for excluding mods; minimum 100 Da
	@infoOnly tinyint = 1,
	@message varchar(512) = '' output
)
AS 

	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	Set @message = ''
	
	-------------------------------------------------------
	-- Validate the Inputs
	-------------------------------------------------------
	--
	Set @massThreshold = IsNull(@massThreshold, 500)
	If @massThreshold < 100
		Set @massThreshold = 100
	
	Set @infoOnly = IsNull(@infoOnly,0)
	
	Set @message = ''
	
	CREATE TABLE #Tmp_MTsToExclude (
		Mass_Tag_ID int NOT NULL,
		Mod_Name varchar(24) NOT NULL,
		ModificationMass float NULL	
	)
	
	-------------------------------------------------------
	-- Find AMT Tags to Exclude
	-------------------------------------------------------
	--
	-- Look for modifications of the form -1261.50, +326.620, +14284.7, etc.
	--
	INSERT INTO #Tmp_MTsToExclude (Mass_Tag_ID, Mod_Name)
	SELECT MTMI.Mass_Tag_ID,
	       MTMI.Mod_Name
	FROM T_Mass_Tag_Mod_Info MTMI
	     INNER JOIN T_Mass_Tags MT
	       ON MTMI.Mass_Tag_ID = MT.Mass_Tag_ID
	WHERE (MTMI.Mod_Name LIKE '[-+][0-9][0-9][0-9]%') AND
	      (MT.PMT_Quality_Score > 0)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Convert the numeric Mod_Name values to a mass
	UPDATE #Tmp_MTsToExclude
	SET ModificationMass = CAST(Mod_Name AS float) 
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


	-- Delete entries that have a mass below the threshold
	DELETE FROM #Tmp_MTsToExclude
	WHERE Abs(IsNull(ModificationMass, 0)) < @massThreshold
	
	
	If @infoOnly <> 0
	Begin
		SELECT * 
		FROM #Tmp_MTsToExclude
		ORDER BY ModificationMass
	End
	Else
	Begin
		UPDATE T_Mass_Tags
		SET PMT_Quality_Score = 0
		FROM T_Mass_Tags Target
		     INNER JOIN #Tmp_MTsToExclude Src
		       ON Target.Mass_Tag_ID = Src.Mass_Tag_ID
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		
		Set @message = 'Changed PMT Quality Score to 0 for ' + cast(@myRowCount as varchar(12)) + ' AMT tags with numeric-based modification mass values above threshold ' + Cast(@massThreshold as varchar(18))
		
		exec PostLogEntry 'Normal', @message, 'ExcludeImplausibleMSAlignResults'

	End
	
	Return @myError


GO
