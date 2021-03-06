/****** Object:  StoredProcedure [dbo].[AddFTICRUmcInternalStdMatch] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.AddFTICRUmcInternalStdMatch
/****************************************************	
**	Adds row to the T_FTICR_UMC_InternalStdDetails
**  Modelled after AddFTICRUmcMatch
**
**	Returns 0 if success; error number on failure
**
**	Auth:	mem
**	Date:	12/31/2003 
**			01/02/2004 mem
**			07/14/2004 mem - renamed @MatchScore parameter to @MatchingMemberCount and added Matching_Member_Count column update in T_FTICR_UMC_NETLockerDetails
**						   - added the @MatchScore parameter
**			07/27/2004 mem - added the @DelMatchScore parameter
**			05/16/2005 mem - switched to using Seq_ID for the Locker ID
**			05/28/2005 mem - renamed column Predicted_GANET to Predicted_NET
**			12/20/2005 mem - Renamed SP from AddFTICRUmcNETLockerMatch to AddFTICRUmcInternalStdMatch
**			10/07/2010 mem - Added parameter @UniquenessProbability
**						   - Changed @MatchingMemberCount from float to int
**			10/11/2010 mem - Added parameter @FDRThreshold (value between 0 and 1)
**			11/10/2011 mem - Added parameters @wSTAC an @wSTACFDR
**
****************************************************/
(
	@UMCResultsID int,					-- reference to T_FTICR_UMC_Results
	@SeqID int,							-- reference to Internal Standard present in T_Mass_Tags
	@MatchingMemberCount int,			-- Number of members in UMC matching Mass Tag ID
	@MatchScore decimal(9,5)=-1,		-- Value between 0 and 1 specifying likelihood (aka probability) of match, given density of region; -1 if undefined; either SLiC score or STAC Score
	@MatchState tinyint=6,				-- Match State (1=New, 5=Not Hit, 6=Hit, see T_FPR_State_Name)
	@ExpectedNET float,					-- NET Value of the Internal Standard
	@DelMatchScore decimal(9,5)=0,		-- Difference between the next lower value's match score and the highest value's match score for all mass tags matching this UMC
	@UniquenessProbability real = 0,	-- Uniqueness Probability, computed by STAC (similar to SLiC score in that it indicates the density of the region that a UMC is matching one or more AMT tags)
	@FDRThreshold real = 1,				-- FDR Threshold that the given STAC score corresponds to; will be 1 if @MatchScore is SLiC Score
	@wSTAC real = null,					-- Weighted STAC score (simply STAC times UniquenessProbability aka STAC * UP)
	@wSTACFDR real = 1					-- FDR associatd with the wSTAC score
)
As
	Set NoCount On

	Declare @ReturnValue int
	Set @ReturnValue=0
	
	--append new row to the T_FTICR_UMC_InternalStdDetails
	INSERT INTO T_FTICR_UMC_InternalStdDetails( UMC_Results_ID,
	                                            Seq_ID,
	                                            Match_Score,
	                                            Match_State,
	                                            Expected_NET,
	                                            Matching_Member_Count,
	                                            Del_Match_Score,
	                                            Uniqueness_Probability,
	                                            FDR_Threshold,
	                                            wSTAC,
	                                            wSTAC_FDR_Threshold )
	VALUES (@UMCResultsID, 
            @SeqID, 
            @MatchScore, 
            @MatchState, 
            @ExpectedNET, 
            @MatchingMemberCount,
            @DelMatchScore, 
            @UniquenessProbability,
            @FDRThreshold,
            @wSTAC,
            @wSTACFDR)
	--
	Set @ReturnValue=@@ERROR
	
Done:
	Return @ReturnValue


GO
GRANT EXECUTE ON [dbo].[AddFTICRUmcInternalStdMatch] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddFTICRUmcInternalStdMatch] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AddFTICRUmcInternalStdMatch] TO [MTS_DB_Lite] AS [dbo]
GO
