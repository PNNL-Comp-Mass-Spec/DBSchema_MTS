/****** Object:  Table [dbo].[T_MTS_DB_Types] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MTS_DB_Types](
	[DB_Type_ID] [tinyint] NOT NULL,
	[DB_Type_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[DB_Name_Prefix] [varchar](8) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_MTS_DB_Types] PRIMARY KEY CLUSTERED 
(
	[DB_Type_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

GO
