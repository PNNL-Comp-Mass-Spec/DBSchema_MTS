/****** Object:  StoredProcedure [dbo].[AddFTICRUmcNETLockerMatch] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.AddFTICRUmcNETLockerMatch
/****************************************************	
**	Adds row to the T_FTICR_UMC_NETLockerDetails table
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
**			12/20/2005 mem - Updated to call AddFTICRUmcInternalStdMatch
**
****************************************************/
(
	@UMCResultsID int,					-- reference to T_FTICR_UMC_Results
	@GANETLockerID int,					-- reference to Internal Standard present in T_Mass_Tags
	@MatchingMemberCount float,			-- Number of members in UMC matching Mass Tag ID
	@MatchScore decimal(9,5)=-1,		-- Value between 0 and 1 specifying likelihood (aka probability) of match, given density of region; -1 if undefined
	@MatchState tinyint=6,				-- Match State (1=New, 5=Not Hit, 6=Hit, see T_FPR_State_Name)
	@PredictedGANET float,				-- NET Value of the GANET_Locker
	@DelMatchScore decimal(9,5)=0		-- Difference between the next lower value's match score and the highest value's match score for all mass tags matching this UMC
)
As
	Set NoCount On

	Declare @ReturnValue int
	Set @ReturnValue=0
	
	Exec @ReturnValue = AddFTICRUmcInternalStdMatch @UMCResultsID, @GANETLockerID, @MatchScore, @MatchState, @PredictedGANET, @MatchingMemberCount, @DelMatchScore
	
Done:
	Return @ReturnValue


GO
GRANT EXECUTE ON [dbo].[AddFTICRUmcNETLockerMatch] TO [DMS_SP_User]
GO
GRANT VIEW DEFINITION ON [dbo].[AddFTICRUmcNETLockerMatch] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[AddFTICRUmcNETLockerMatch] TO [MTS_DB_Lite]
GO
