/****** Object:  Table [dbo].[T_Mass_Tag_Conformers_Observed] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Mass_Tag_Conformers_Observed](
	[Conformer_ID] [int] IDENTITY(1,1) NOT NULL,
	[Mass_Tag_ID] [int] NOT NULL,
	[Charge] [smallint] NOT NULL,
	[Conformer] [smallint] NOT NULL,
	[Drift_Time_Avg] [real] NULL,
	[Drift_Time_StDev] [real] NULL,
	[Obs_Count] [int] NULL,
	[Last_Affected] [datetime] NULL,
 CONSTRAINT [PK_T_Mass_Tag_Conformers_Observed] PRIMARY KEY CLUSTERED 
(
	[Conformer_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Mass_Tag_Conformers_Observed_MT_Charge_Conformer] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_Mass_Tag_Conformers_Observed_MT_Charge_Conformer] ON [dbo].[T_Mass_Tag_Conformers_Observed] 
(
	[Mass_Tag_ID] ASC,
	[Charge] ASC,
	[Conformer] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Conformers_Observed]  WITH CHECK ADD  CONSTRAINT [FK_T_Mass_Tag_Conformers_Observed_T_Mass_Tags] FOREIGN KEY([Mass_Tag_ID])
REFERENCES [T_Mass_Tags] ([Mass_Tag_ID])
GO
ALTER TABLE [dbo].[T_Mass_Tag_Conformers_Observed] CHECK CONSTRAINT [FK_T_Mass_Tag_Conformers_Observed_T_Mass_Tags]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Conformers_Observed] ADD  CONSTRAINT [DF_T_Mass_Tag_Conformers_Observed_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
