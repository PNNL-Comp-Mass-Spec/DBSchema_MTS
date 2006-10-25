/****** Object:  Table [dbo].[T_FTICR_UMC_ResultDetails] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_FTICR_UMC_ResultDetails](
	[UMC_ResultDetails_ID] [int] IDENTITY(1,1) NOT NULL,
	[UMC_Results_ID] [int] NOT NULL,
	[Mass_Tag_ID] [int] NOT NULL,
	[Match_Score] [decimal](9, 5) NOT NULL,
	[Match_State] [tinyint] NOT NULL CONSTRAINT [DF_T_FTICR_UMC_ResultDetails_Match_State]  DEFAULT (1),
	[Expected_NET] [real] NULL,
	[Mass_Tag_Mods] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_FTICR_UMC_ResultDetails_Mass_Tag_Mods]  DEFAULT (''),
	[Mass_Tag_Mod_Mass] [float] NOT NULL CONSTRAINT [DF_T_FTICR_UMC_ResultDetails_Mass_Tag_Mod_Mass]  DEFAULT (0),
	[Matching_Member_Count] [int] NOT NULL,
	[Del_Match_Score] [decimal](9, 5) NOT NULL,
 CONSTRAINT [PK_T_FTICR_UMC_ResultDetails] PRIMARY KEY NONCLUSTERED 
(
	[UMC_ResultDetails_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_FTICR_UMC_ResultDetails] ******/
CREATE CLUSTERED INDEX [IX_T_FTICR_UMC_ResultDetails] ON [dbo].[T_FTICR_UMC_ResultDetails] 
(
	[UMC_Results_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_FTICR_UMC_ResultDetails_Mass_Tag_ID] ******/
CREATE NONCLUSTERED INDEX [IX_T_FTICR_UMC_ResultDetails_Mass_Tag_ID] ON [dbo].[T_FTICR_UMC_ResultDetails] 
(
	[Mass_Tag_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_FTICR_UMC_ResultDetails_MatchState] ******/
CREATE NONCLUSTERED INDEX [IX_T_FTICR_UMC_ResultDetails_MatchState] ON [dbo].[T_FTICR_UMC_ResultDetails] 
(
	[Match_State] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_FTICR_UMC_ResultDetails]  WITH NOCHECK ADD  CONSTRAINT [FK_T_FTICR_UMC_ResultDetails_T_FPR_State_Name] FOREIGN KEY([Match_State])
REFERENCES [T_FPR_State_Name] ([Match_State])
ON UPDATE CASCADE
GO
ALTER TABLE [dbo].[T_FTICR_UMC_ResultDetails] CHECK CONSTRAINT [FK_T_FTICR_UMC_ResultDetails_T_FPR_State_Name]
GO
ALTER TABLE [dbo].[T_FTICR_UMC_ResultDetails]  WITH NOCHECK ADD  CONSTRAINT [FK_T_FTICR_UMC_ResultDetails_T_FTICR_UMC_Results] FOREIGN KEY([UMC_Results_ID])
REFERENCES [T_FTICR_UMC_Results] ([UMC_Results_ID])
GO
ALTER TABLE [dbo].[T_FTICR_UMC_ResultDetails] CHECK CONSTRAINT [FK_T_FTICR_UMC_ResultDetails_T_FTICR_UMC_Results]
GO
ALTER TABLE [dbo].[T_FTICR_UMC_ResultDetails]  WITH NOCHECK ADD  CONSTRAINT [FK_T_FTICR_UMC_ResultDetails_T_Mass_Tags] FOREIGN KEY([Mass_Tag_ID])
REFERENCES [T_Mass_Tags] ([Mass_Tag_ID])
GO
ALTER TABLE [dbo].[T_FTICR_UMC_ResultDetails] CHECK CONSTRAINT [FK_T_FTICR_UMC_ResultDetails_T_Mass_Tags]
GO
