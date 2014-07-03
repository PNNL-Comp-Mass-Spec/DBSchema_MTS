/****** Object:  Table [dbo].[T_Mass_Tag_Conformers_Predicted] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Mass_Tag_Conformers_Predicted](
	[Mass_Tag_ID] [int] NOT NULL,
	[Charge] [smallint] NOT NULL,
	[Avg_Obs_NET] [real] NOT NULL,
	[Predicted_Drift_Time] [real] NULL,
	[Update_Required] [tinyint] NOT NULL,
	[Last_Affected] [datetime] NULL,
 CONSTRAINT [PK_T_Mass_Tag_Conformers_Predicted] PRIMARY KEY CLUSTERED 
(
	[Mass_Tag_ID] ASC,
	[Charge] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Mass_Tag_Conformers_Predicted] ADD  CONSTRAINT [DF_T_Mass_Tag_Conformers_Predicted_Update_Required]  DEFAULT ((1)) FOR [Update_Required]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Conformers_Predicted] ADD  CONSTRAINT [DF_T_Mass_Tag_Conformers_Predicted_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
ALTER TABLE [dbo].[T_Mass_Tag_Conformers_Predicted]  WITH CHECK ADD  CONSTRAINT [FK_T_Mass_Tag_Conformers_Predicted_T_Mass_Tags] FOREIGN KEY([Mass_Tag_ID])
REFERENCES [dbo].[T_Mass_Tags] ([Mass_Tag_ID])
GO
ALTER TABLE [dbo].[T_Mass_Tag_Conformers_Predicted] CHECK CONSTRAINT [FK_T_Mass_Tag_Conformers_Predicted_T_Mass_Tags]
GO
