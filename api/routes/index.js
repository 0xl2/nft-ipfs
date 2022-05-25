const express = require('express');
const { ethers } = require("ethers");
const empty = require('is-empty');
const ipfsHttpClient = require('ipfs-http-client');

const ipfsClient = ipfsHttpClient.create('https://ipfs.infura.io:5001/api/v0');

const nftABI = require('../abi/MyNFT.json');
const config = require('../config/config.json');

const router = express.Router();
const provider = new ethers.providers.JsonRpcProvider(config.rpc_url);
const signer = new ethers.Wallet(config.p_key, provider);
const nftContract = new ethers.Contract(
  config.nft_address,
  nftABI.abi,
  provider
);

function NewArray(size)
{
    let x = [];
    for( let i = 1; i <= size; i++ ) x.push(i);
    return x;
}

/* GET home page. */
router.get('/', (req, res, next) => {
  res.render('index', { status: 'API server is running' });
});

router.post('/nftmint', async(req, res) => {
  const { wallet } = req.body;
  if(empty(wallet)) return res.json({ status: false, err_msg: 'Invalid address' });
  if(!req.files || !req.files.attached) return res.json({ status: false, err_msg: 'No file' });

  try {
    const attachFile = req.files.attached;
    const fileName = attachFile.name;

    let metaData = "";
    if(fileName.indexOf('.txt') >= 0 && attachFile.mimetype == "text/plain") {
      if(attachFile.size > 1024) return res.json({status: false, err_msg: "Size is bigger than 1KG" });

      metaData = attachFile.data.toString('utf8');
    } else if(attachFile.mimetype == "image/jpeg") {
      const { path } = await ipfsClient.add(attachFile.data);
      metaData = "https://ipfs.io/ipfs/" + path;
    }

    if(metaData && metaData.length > 0) {
      try {
        const userAddr = ethers.utils.getAddress(wallet);
        const tx = await nftContract.connect(signer).mintNFT(userAddr, metaData);
        await tx.wait();

        const tokenId = Number(await nftContract.getTokenCount());
        return res.json({ status: true, data: Number(tokenId) });
      } catch(err1) {
        console.log(err1, "err1 here");
        return res.json({ status: false, err_msg: err1.error.error.toString() });
      }
    } else {
      return res.json({status: false, err_msg: "Invalid attached file"});
    }
  } catch(err) {
    console.log(err);
    return res.json({ status: false, err_msg: JSON.stringify(err) });
  }
});

router.get('/nftmint', async(req, res) => {
  try {
    const totalCnt = Number(await nftContract.getTokenCount());
    console.log(totalCnt);

    let respData = [];
    if(totalCnt > 0) {
      respData = await Promise.all(NewArray(totalCnt).map(async(item) => {
        const metaInfo = await nftContract.tokenURI(item.toString());
        return {
          tokenId: item,
          metaInfo
        }
      }));
    }

    return res.json({ status: true, data: respData });
  } catch(err) {
    console.log(err);
    return res.json({ status: false, err_msg: JSON.stringify(err) });
  }
});

router.get('/nftmint/:id', async(req, res) => {
  if(empty(req.params.id)) return res.json({ status: false, err_msg: "Invalid tokenId" });

  try {
    const tokenId = req.params.id.toString();
    const metaInfo = await nftContract.tokenURI(tokenId);
    return res.json({ status: true, data: { tokenId, metaInfo } });
  } catch(err) {
    console.log(err);
    return res.json({ status: false, err_msg: "Invalid tokenId" });
  }
});

module.exports = router;
