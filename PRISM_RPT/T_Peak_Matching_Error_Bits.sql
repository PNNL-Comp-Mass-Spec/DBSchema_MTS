/****** Object:  Table [dbo].[T_Peak_Matching_Error_Bits] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peak_Matching_Error_Bits](
	[Processing_Error_Bit] [int] NOT NULL,
	[Processing_Error_Bit_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Peak_Matching_Error_Bits] PRIMARY KEY CLUSTERED 
(
	[Processing_Error_Bit] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Peak_Matching_Error_Bits]  WITH CHECK ADD  CONSTRAINT [CK_T_Peak_Matching_Error_Bits] CHECK  ((round((log10([Processing_Error_Bit]) / log10(2)),0) = log10([Processing_Error_Bit]) / log10(2)))
GO
ALTER TABLE [dbo].[T_Peak_Matching_Error_Bits] CHECK CONSTRAINT [CK_T_Peak_Matching_Error_Bits]
GO
