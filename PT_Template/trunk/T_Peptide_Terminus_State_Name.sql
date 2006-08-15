/****** Object:  Table [dbo].[T_Peptide_Terminus_State_Name] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peptide_Terminus_State_Name](
	[Terminus_State] [tinyint] NOT NULL,
	[Terminus_State_Name] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Peptide_Terminus_State_Name] PRIMARY KEY CLUSTERED 
(
	[Terminus_State] ASC
) ON [PRIMARY]
) ON [PRIMARY]

GO
