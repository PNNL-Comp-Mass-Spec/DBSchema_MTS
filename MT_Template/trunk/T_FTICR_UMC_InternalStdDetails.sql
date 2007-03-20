/****** Object:  Table [dbo].[T_FTICR_UMC_InternalStdDetails] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_FTICR_UMC_InternalStdDetails](
	[UMC_InternalStdDetails_ID] [int] IDENTITY(1,1) NOT NULL,
	[UMC_Results_ID] [int] NOT NULL,
	[Seq_ID] [int] NOT NULL,
	[Match_Score] [decimal](9, 5) NOT NULL,
	[Match_State] [tinyint] NOT NULL,
	[Expected_NET] [real] NOT NULL,
	[Matching_Member_Count] [int] NOT NULL,
	[Del_Match_Score] [decimal](9, 5) NOT NULL,
 CONSTRAINT [PK_T_FTICR_UMC_InternalStdDetails] PRIMARY KEY NONCLUSTERED 
(
	[UMC_InternalStdDetails_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_FTICR_UMC_InternalStdDetails] ******/
CREATE CLUSTERED INDEX [IX_T_FTICR_UMC_InternalStdDetails] ON [dbo].[T_FTICR_UMC_InternalStdDetails] 
(
	[UMC_Results_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_FTICR_UMC_InternalStdDetails]  WITH CHECK ADD  CONSTRAINT [FK_T_FTICR_UMC_InternalStdDetails_T_FPR_State_Name] FOREIGN KEY([Match_State])
REFERENCES [T_FPR_State_Name] ([Match_State])
GO
ALTER TABLE [dbo].[T_FTICR_UMC_InternalStdDetails] CHECK CONSTRAINT [FK_T_FTICR_UMC_InternalStdDetails_T_FPR_State_Name]
GO
ALTER TABLE [dbo].[T_FTICR_UMC_InternalStdDetails]  WITH CHECK ADD  CONSTRAINT [FK_T_FTICR_UMC_InternalStdDetails_T_FTICR_UMC_Results] FOREIGN KEY([UMC_Results_ID])
REFERENCES [T_FTICR_UMC_Results] ([UMC_Results_ID])
GO
ALTER TABLE [dbo].[T_FTICR_UMC_InternalStdDetails] CHECK CONSTRAINT [FK_T_FTICR_UMC_InternalStdDetails_T_FTICR_UMC_Results]
GO
ALTER TABLE [dbo].[T_FTICR_UMC_InternalStdDetails]  WITH NOCHECK ADD  CONSTRAINT [FK_T_FTICR_UMC_InternalStdDetails_T_Mass_Tags] FOREIGN KEY([Seq_ID])
REFERENCES [T_Mass_Tags] ([Mass_Tag_ID])
GO
ALTER TABLE [dbo].[T_FTICR_UMC_InternalStdDetails] CHECK CONSTRAINT [FK_T_FTICR_UMC_InternalStdDetails_T_Mass_Tags]
GO
