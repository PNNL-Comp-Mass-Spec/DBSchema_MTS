/****** Object:  UserDefinedFunction [dbo].[calcDiscriminantScoreNorm] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION dbo.calcDiscriminantScoreNorm
/***************************
** Calculates Probability values for a Peptide based on Discriminant score
** 
** Auth:	EFS
** Date:	09/01/2004
**			07/06/2005 mem - Updated to group all @chargeState values >= 3 together
**			02/19/2009 mem - Changed @dbSize to bigint
** 
***************************/
(	@DiscriminantScore float, 
	@chargeState int,
	@dbSize as bigint				-- the number of residues present in the peptide database (aka fasta file)
) 
	RETURNS float 
AS  
BEGIN
	
	/*
	** Old method which did not normalize by database size:
	**
	**	If @ChargeState=1
	**		return dbo.Sigmoid(@DiscriminantScore,1,-0.21,0.45)
	**	If @ChargeState=2
	**		return dbo.Sigmoid(@DiscriminantScore,1,-0.55,0.21)
	**	If @ChargeState>=3
	**		return dbo.Sigmoid(@DiscriminantScore,1,-1.21,0.29)
	**
	**	return 0;
	**
	*/
	
	-- calculate probability for a yeast-like db
	If @dbSize <= 5050000
	begin
		If @ChargeState=1
			return dbo.Sigmoid(@DiscriminantScore,1,-0.32,0.47)
		If @ChargeState=2
			return dbo.Sigmoid(@DiscriminantScore,1,-0.78,0.25)
		If @ChargeState>=3
			return dbo.Sigmoid(@DiscriminantScore,1,-1.54,0.37)
	end
	
	-- calculate probability for a drosophila-like db
	If @dbSize > 5050000 and @dbSize <= 9540000
	begin
		If @ChargeState=1
			return dbo.Sigmoid(@DiscriminantScore,1,-0.36,0.54)
		If @ChargeState=2
			return dbo.Sigmoid(@DiscriminantScore,1,-0.78,0.25)
		If @ChargeState>=3
			return dbo.Sigmoid(@DiscriminantScore,1,-1.54,0.37)
	end
	
	-- calculate probability for a rat-like db
	If @dbSize > 9540000 and @dbSize <= 16000000
	begin
		If @ChargeState=1
			return dbo.Sigmoid(@DiscriminantScore,1,-0.20,0.79)
		If @ChargeState=2 and @DiscriminantScore <= .5
			return dbo.Sigmoid(@DiscriminantScore,.82,-0.63,0.31)
		If @ChargeState=2 and @DiscriminantScore > .5 and @DiscriminantScore < 3.5
			return 0.062 * @DiscriminantScore + 0.763
		If @ChargeState=2 and @DiscriminantScore >= 3.5
			return 1.0
		If @ChargeState>=3
			return dbo.Sigmoid(@DiscriminantScore,1,-0.92,0.62)
	end
	
	-- calculate probability for a human-like db
	If @dbSize > 16000000
	begin
		If @ChargeState=1
			return dbo.Sigmoid(@DiscriminantScore,1,-0.167,0.79)
		If @ChargeState=2 and @DiscriminantScore <= .5
			return dbo.Sigmoid(@DiscriminantScore,.82,-0.63,0.31)
		If @ChargeState=2 and @DiscriminantScore > .5 and @DiscriminantScore < 3.5
			return 0.062 * @DiscriminantScore+ 0.763
		If @ChargeState=2 and @DiscriminantScore >= 3.5
			return 1.0
		If @ChargeState>=3 and @DiscriminantScore <= 0
			return dbo.Sigmoid(@DiscriminantScore,.87,-1.52,0.37)
		If @ChargeState>=3 and @DiscriminantScore > 0 and @DiscriminantScore < 3
			return 0.039 * @DiscriminantScore+ 0.833
		If @ChargeState>=3 and @DiscriminantScore >= 3
			return 1.0
	end
	
	return 0;
END


GO
