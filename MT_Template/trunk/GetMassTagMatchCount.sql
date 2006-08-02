SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetMassTagMatchCount]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetMassTagMatchCount]
GO


CREATE PROCEDURE dbo.GetMassTagMatchCount
/****************************************************************
**  Desc: Returns the number of mass tags matching the given filters
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: See comments below
**
**  Auth: mem
**	Date: 09/09/2005
**  
****************************************************************/
(
	@ConfirmedOnly tinyint = 0,					-- Mass Tag must have Is_Confirmed = 1
	@MinimumHighNormalizedScore float = 0,		-- The minimum value required for High_Normalized_Score; 0 to allow all
	@MinimumPMTQualityScore decimal(9,5) = 0,	-- The minimum PMT_Quality_Score to allow; 0 to allow all
	@MinimumHighDiscriminantScore real = 0		-- The minimum High_Discriminant_Score to allow; 0 to allow all
)
As
	Set NoCount On

	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @S varchar(1024)
	

	Set @S = ''
	Set @S = @S + ' SELECT COUNT(*) As TotalMassTags'
	Set @S = @S + ' FROM T_Mass_Tags'
	Set @S = @S + ' WHERE High_Normalized_Score >= ' + Convert(varchar(9), @MinimumHighNormalizedScore) + ' AND'
	Set @S = @S +       ' High_Discriminant_Score >= ' + Convert(varchar(9), @MinimumHighDiscriminantScore) + ' AND'
	Set @S = @S +       ' PMT_Quality_Score >= ' + Convert(varchar(9), @MinimumPMTQualityScore)

	If @ConfirmedOnly <> 0
		Set @S = @S +       ' AND Is_Confirmed =1 '
	
	Exec (@S)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount


Done:
	Return @myError


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetMassTagMatchCount]  TO [DMS_SP_User]
GO

