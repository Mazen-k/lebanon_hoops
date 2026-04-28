-- Fan Shop items table.
-- Apply once against the BasketballApp database.
-- Run after BasketballApp.sql.

CREATE TABLE IF NOT EXISTS public.shop_items (
  item_id          SERIAL PRIMARY KEY,
  name             VARCHAR(200)   NOT NULL,
  subtitle         VARCHAR(300),
  category         VARCHAR(50)    NOT NULL DEFAULT 'All Items',
  price            NUMERIC(10, 2) NOT NULL,
  original_price   NUMERIC(10, 2),
  quantity_available INTEGER      NOT NULL DEFAULT 0,
  image_url        TEXT,
  badge            VARCHAR(100),
  is_featured      BOOLEAN        NOT NULL DEFAULT FALSE,
  description      TEXT,
  created_at       TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Seed with the items shown in the original design
INSERT INTO public.shop_items (name, subtitle, category, price, quantity_available, image_url, badge, is_featured)
VALUES
  ('Cedar Elite Home Jersey',  '2024 Season Edition • Moisture-wicking fabric', 'Jerseys',      120.00, 50,  'https://lh3.googleusercontent.com/aida-public/AB6AXuCBhqlu88FtI77R06HoxfnJ4gt9nK2r9_eKpBsj-5ezeHa6KFh5DgYAD5pUEcAGgbQ_bsPf_xAbDxXS1wIM9og7ZzAw0QSc25-RUITZLadjEIGk41cMkf5iU8ejUYtIQc5SUeS_0wlT-Ub-mrXaptJQWTbEDWrHvxbZIrgs_eQMJTNrFExUilIfHEqRwMHWtZp4w0vkbIxrnPzgp3nPzAwUT9faSzu6KspN5KBmV1BxQCJdE2qvxK2-4AUCNx4Tb2PuLZBmAEUyAKfD', 'Authentic', TRUE),
  ('The Finals Snapback',      'Adjustable • One size',                          'Headwear',     35.00,  120, 'https://lh3.googleusercontent.com/aida-public/AB6AXuCkxKuLef9iVRYDuD1TGyLt3aoYGn5-s01ceYK5GgkxRkG5kSz7O9w7HGXNsYSe8z35Zir1tI4UBWl2qcyHezxoUZZzmVfJCmdZo4tsaKlWnPxw1ZGYR3RODtaL-JLUN7WeusxUOb2ZJCmC0y535uMvDwt_TlOUdZWITFd9Ln3lynSe1R6W0TdfFPb8q8CzJh7A4paSs2Zo_Xy8NzKPfy1J8Z81qpJGWq-eqjd1WIsvNH0x-nxhLB4hKuS1HfyFpqf45p5S6U4kHM86', NULL,         FALSE),
  ('Official Game Ball',       'Pro League Standard Size 7',                     'Training',     85.00,  30,  'https://lh3.googleusercontent.com/aida-public/AB6AXuBgYl9M_nujrgtwP53a-ldvxavTlBsOXL16EnXfozUWPEpu4SVb85fI_GbuH1jJnDj48gGCIHRBgKHKvrdAF0pK7bgENnDiPMu0kZgExCO0ANoi7GqQ2mcjCqgVnpJoMnQTduXRrsNLcf2g0c5deKONXRFogZc2C2CfT7pqunoD1EA4qrG6j4uryHiLE0XrXm0-rmx7X0tse19XbEv_LuMwr3rpfB5VnwdKd_p9vNP8eqOG9ytyE1wa7lwJOJ8LNB7YztFfSxN8dI1L', NULL,         FALSE),
  ('Sideline Fleece Hoodie',   'Available in Grey / Black',                      'Training',     65.00,  75,  'https://lh3.googleusercontent.com/aida-public/AB6AXuBwk91XV2mPKLowey1YFyKShlG97mVenZFlTba6h_9hNfOP9V0fuH3YilG2KZn888biDYYyXRVrxUbtPmDbwQxF2B5r83QatqSGobWao_hDW4O_OFvY6nqhquO0TZhr2s0IRlgJXRrPx3Rt7NuK_0YczPeQzHLZF2Bp2wFV5P0oNAZO4IVL8Y6FrozOYqaV7SPGWQ1OeBX8f-fE5ylVcTatdy18vRuV4Y7R8jzPBi31doQAwodqt3TctbSH9l-EAq-cSl3wFvN6X1OW', NULL,         FALSE),
  ('Autographed Frame',        'Hand-signed by 2023 MVP',                        'Memorabilia',  245.00, 10,  'https://lh3.googleusercontent.com/aida-public/AB6AXuCMWpwqDCrQaBY9F89MN3Z03MJRvCg5AkU80hRSo7LE6TgA6T6uu0nXKnuSninjUjAdaPAChy7JuAY-jet4JywTbiICaCbPuuE8IloNBfRpuYEgAUhjd0eEgQudSTn0tTPvyT2hbkx9nmPwdMraoI9K3U6YuZuEDRqvunBTjNQSjdmAn64-4e_CrAIgp-MhvxwFS1DpJUUcGAah0_zljZCY3hG6cZJuaDYLVl-8l2F8UdEhkWe7_Q7ZGX8Xm4MLAtNE7XCpAckZpWRr', NULL,         FALSE)
ON CONFLICT DO NOTHING;
