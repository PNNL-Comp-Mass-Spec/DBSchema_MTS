if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peak_Matching_Error_Bits]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peak_Matching_Error_Bits]
GO

CREATE TABLE [T_Peak_Matching_Error_Bits] (
        [Processing_Error_Bit] [int] NOT NULL ,
        [Processing_Error_Bit_Name] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
        CONSTRAINT [PK_T_Peak_Matching_Error_Bits] PRIMARY KEY  CLUSTERED 
        (
                [Processing_Error_Bit]
        ) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
        CONSTRAINT [CK_T_Peak_Matching_Error_Bits] CHECK (round((log10([Processing_Error_Bit]) / log10(2)),0) = log10([Processing_Error_Bit]) / log10(2))
) ON [PRIMARY]
GO
