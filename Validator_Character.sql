USE [DigitalLibrary]
GO
/****** Object:  UserDefinedFunction [dbo].[Validator_Character]    Script Date: 06/03/2017 09:46:35 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Hale Kavoosi>
-- Create date: <06/03/2017>
-- Description:	<این تابع برای چک کردن این است که فیلد تنها شامل کاراکترهای خاص نباشد >
-- =============================================
ALTER FUNCTION [dbo].[Validator_Character]

(  @TextValue nvarchar(MAX))

RETURNS int
AS
BEGIN

   --Return Value=0 --->  حاوی کارکتر غیر مجاز است
   --Return Value=1 --->  حاوی کارکتر غیر مجاز نیست
   
	--ِبراي تعيين محدوده ي كاركترهاي مجاز
	Declare @validChar nvarchar(100) 
	Set @validChar = N'['
	--براي كاركترهاي فارسي
	+nchar(1570)+'-'+nchar(1594)
	+nchar(1601)+'-'+nchar(1610)
	+nchar(1655)+'-'+nchar(1745)+'A-Za-z'
		
	--بستن رشته
	Set @validChar = @validChar +']'
	
	--در صورتي كه كاركتر غيرمجاز وجود داشته باشد
	If PATINDEX('%'+@validChar+'%', @TextValue) = 0
		Return 0

	RETURN 1

END
--SELECT [dbo].[Validator_Character] (N'1')