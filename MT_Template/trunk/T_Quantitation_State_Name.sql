/****** Object:  Table [dbo].[T_Quantitation_State_Name] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Quantitation_State_Name](
	[Quantitation_State] [tinyint] NOT NULL,
	[Quantitation_State_Name] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Quantitation_State_Name] PRIMARY KEY CLUSTERED 
(
	[Quantitation_State] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO
