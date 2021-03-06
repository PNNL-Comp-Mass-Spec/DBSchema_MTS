/****** Object:  StoredProcedure [dbo].[AddFTICRUmcMatch] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.AddFTICRUmcMatch
/****************************************************	
**	Adds row to the T_FTICR_UMC_ResultDetails table
**
**	Returns 0 if success; error number on failure
**  
**  Date:	05/22/2003 mem - Initial version; modelled after AddFTICRUmc	
**			06/27/2003 mem
**			08/11/2003 mem
**			11/12/2003 mem - added MassTagMods parameter
**			11/19/2003 mem - added MassTagModMass parameter
**			07/14/2004 mem - renamed @MatchScore parameter to @MatchingMemberCount and added Matching_Member_Count column update in T_FTICR_UMC_ResultDetails
**						   - added the @MatchScore parameter
**			07/27/2004 mem - added the @DelMatchScore parameter
**			05/28/2005 mem - Now populating column Expected_NET
**			10/07/2010 mem - Added parameter @UniquenessProbability
**						   - Changed @MassTagModMass from float to real
**			10/11/2010 mem - Added parameter @FDRThreshold (value between 0 and 1)
**			06/21/2011 mem - Added parameter @ConformerID
**			11/10/2011 mem - Added parameters @wSTAC and @wSTACFDR
**
****************************************************/
(
	@UMCResultsID INT,					-- Reference to T_FTICR_UMC_Results
	@MassTagID INT,						-- Reference to T_Mass_Tags table(matching mass tag)
	@MatchingMemberCount INT,			-- Number of members in UMC matching Mass Tag ID
	@MatchScore decimal(9,5)=-1,		-- Value between 0 and 1 specifying likelihood (aka probability) of match; either SLiC score or STAC Score
	@MatchState TINYINT=1,				-- Match State (1=New, 5=Not Hit, 6=Hit)
	@SetIsConfirmedForMT TINYINT=1,		-- If 1, sets the Is_Confirmed field to 1 for the MassTagID in T_Mass_Tags
	@MassTagMods VARCHAR(50)='',		-- Maximum mod text length is 50 characters
	@MassTagModMass real=0,				-- Mass of the modification applied to this mass tag prior to peak peak matching
	@DelMatchScore decimal(9,5)=0,		-- Difference between the next lower value's match score and the highest value's match score for all mass tags matching this UMC
	@UniquenessProbability real=0,		-- Uniqueness Probability, computed by STAC (similar to SLiC score in that it indicates the density of the region that a UMC is matching one or more AMT tags)
	@FDRThreshold real = 1,				-- FDR Threshold that the given STAC score corresponds to; will be 1 if @MatchScore is SLiC Score
	@ConformerID int = null,			-- ConformerID of the given match (only applicable if matching using Drift Times)
	@wSTAC real = null,					-- Weighted STAC score (simply STAC times UniquenessProbability aka STAC * UP)
	@wSTACFDR real = 1					-- FDR associatd with the wSTAC score
)
As
	SET NOCOUNT ON

	DECLARE @returnvalue INT
	SET @returnvalue=0
	
	declare @Avg_GANET real
	
	-- Use a transaction since two updates
	BEGIN TRANSACTION

	-- Look up the NET value for this mass tag ID	
	SELECT @Avg_GANET = Avg_GANET
	FROM T_Mass_Tags_NET
	WHERE Mass_Tag_ID = @MassTagID
		
	--append new row to the T_FTICR_UMC_ResultDetails table
	INSERT INTO dbo.T_FTICR_UMC_ResultDetails( UMC_Results_ID,
	                                           Mass_Tag_ID,
	                                           Match_Score,
	                                           Match_State,
	                                           Expected_NET,
	                                           Mass_Tag_Mods,
	                                           Mass_Tag_Mod_Mass,
	                                           Matching_Member_Count,
	                                           Del_Match_Score,
	                                           Uniqueness_Probability,
	                                           FDR_Threshold,
	                                           Conformer_ID,
	                                           wSTAC,
	                                           wSTAC_FDR_Threshold )
	VALUES(@UMCResultsID, 
	       @MassTagID, 
	       @MatchScore, 
	       @MatchState, 
	       @Avg_GANET, 
	       IsNull(@MassTagMods, ''), 
	       @MassTagModMass, 
	  @MatchingMemberCount, 
	       @DelMatchScore, 
	       @UniquenessProbability,
	       @FDRThreshold,
	       @ConformerID,
	       @wSTAC,
	       @wSTACFDR)
	--
	SET @returnvalue=@@ERROR
	--
	If @returnvalue <> 0
		Begin
			Rollback Transaction
			Goto Done
		End
	
	If @SetIsConfirmedForMT <> 0
	Begin
		-- Update Is_Confirmed for this MassTagID
		UPDATE T_Mass_Tags
		SET Is_Confirmed = 1
		WHERE Mass_Tag_ID = @MassTagID AND Is_Confirmed < 1
		--
		SET @returnvalue=@@ERROR
	End

	If @returnvalue <> 0
		Begin
			Rollback Transaction
			Goto Done
		End
	Else
		Commit Transaction
	
Done:
	
	RETURN @returnvalue


GO
GRANT EXECUTE ON [dbo].[AddFTICRUmcMatch] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddFTICRUmcMatch] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddFTICRUmcMatch] TO [MTS_DB_Lite] AS [dbo]
GO
