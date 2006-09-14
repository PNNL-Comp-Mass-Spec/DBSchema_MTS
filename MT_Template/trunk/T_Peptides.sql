/****** Object:  Table [dbo].[T_Peptides] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peptides](
	[Peptide_ID] [int] NOT NULL,
	[Analysis_ID] [int] NOT NULL,
	[Scan_Number] [int] NULL,
	[Number_Of_Scans] [smallint] NULL,
	[Charge_State] [smallint] NULL,
	[MH] [float] NULL,
	[Multiple_Proteins] [smallint] NULL,
	[Peptide] [varchar](850) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Mass_Tag_ID] [int] NOT NULL,
	[GANET_Obs] [real] NULL,
	[State_ID] [tinyint] NOT NULL CONSTRAINT [DF_T_Peptides_State]  DEFAULT (1),
	[Scan_Time_Peak_Apex] [real] NULL,
	[Peak_Area] [real] NULL,
	[Peak_SN_Ratio] [real] NULL,
	[Max_Obs_Area_In_Job] [tinyint] NOT NULL CONSTRAINT [DF_T_Peptides_Max_Obs_Area_In_Job]  DEFAULT (0),
 CONSTRAINT [PK_T_Peptides] PRIMARY KEY CLUSTERED 
(
	[Peptide_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Peptides_Analysis_ID_Mass_Tag_ID] ******/
CREATE NONCLUSTERED INDEX [IX_T_Peptides_Analysis_ID_Mass_Tag_ID] ON [dbo].[T_Peptides] 
(
	[Analysis_ID] ASC,
	[Mass_Tag_ID] ASC
) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Peptides_Mass_Tag_ID] ******/
CREATE NONCLUSTERED INDEX [IX_T_Peptides_Mass_Tag_ID] ON [dbo].[T_Peptides] 
(
	[Mass_Tag_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Peptides_Peptide] ******/
CREATE NONCLUSTERED INDEX [IX_T_Peptides_Peptide] ON [dbo].[T_Peptides] 
(
	[Peptide] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Peptides_Peptide_ID_Mass_Tag_ID] ******/
CREATE NONCLUSTERED INDEX [IX_T_Peptides_Peptide_ID_Mass_Tag_ID] ON [dbo].[T_Peptides] 
(
	[Peptide_ID] ASC,
	[Mass_Tag_ID] ASC
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Peptides]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Peptides_T_Analysis_Description] FOREIGN KEY([Analysis_ID])
REFERENCES [T_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_Peptides] CHECK CONSTRAINT [FK_T_Peptides_T_Analysis_Description]
GO
ALTER TABLE [dbo].[T_Peptides]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Peptides_T_Mass_Tags] FOREIGN KEY([Mass_Tag_ID])
REFERENCES [T_Mass_Tags] ([Mass_Tag_ID])
GO
ALTER TABLE [dbo].[T_Peptides] CHECK CONSTRAINT [FK_T_Peptides_T_Mass_Tags]
GO
ALTER TABLE [dbo].[T_Peptides]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Peptides_T_Peptide_State_Name] FOREIGN KEY([State_ID])
REFERENCES [T_Peptide_State_Name] ([State_ID])
GO
ALTER TABLE [dbo].[T_Peptides] CHECK CONSTRAINT [FK_T_Peptides_T_Peptide_State_Name]
GO
